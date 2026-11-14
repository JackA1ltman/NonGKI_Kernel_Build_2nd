#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从 boot.img / kernel Image 提取内核 .config（IKCONFIG）

背景：NonGKI_Kernel_Build_2nd 的 DEFCONFIG_FROM_BOOT 那段代码有 bug
      （[[ -f "$BOOT_SOURCE" ]] 判本地文件，但内部又 curl 下载 URL）。
      更稳的做法是：本地先提出 defconfig，直接提交到 fork 仓库，
      让构建脚本走 DEFCONFIG_NAME 读本地文件这条路。

原理：
     内核开了 CONFIG_IKCONFIG 时，gzip 压缩的 .config 会被嵌进内核镜像，
      开头 8 字节是 magic "IKCFG_ST"，结尾是 "IKCFG_ED"。
      中间就是 gzip 流。

用法：
    # 从 boot.img 提（自动解 boot header）
    python ikconfig.py boot.img -o kebab_defconfig

    # 从已解出的 kernel Image 提
    python ikconfig.py Image -o kebab_defconfig

    # 只看能不能找到，不写文件
    python ikconfig.py boot.img --check

    # 抓原厂版本串（版本伪装用，避免人工抄写出错）
    python ikconfig.py boot.img --uname
    # 输出 GITHUB_ENV 格式，可直接喂给 workflow
    python ikconfig.py boot.img --uname --env
"""
import sys
import os
import gzip
import io
import struct
import re

MAGIC_ST = b'IKCFG_ST'
MAGIC_ED = b'IKCFG_ED'
BOOT_MAGIC = b'ANDROID!'


def align(x, p):
    return (x + p - 1) // p * p


def extract_kernel_from_boot(data):
    """从 Android boot.img 里切出 kernel 段"""
    if data[:8] != BOOT_MAGIC:
        return None, "不是 Android boot image"
    version = struct.unpack_from('<I', data, 40)[0]
    if version in (3, 4):
        ps = struct.unpack_from('<I', data, 0x0C)[0]
        ks = struct.unpack_from('<I', data, 0x08)[0]
    else:
        ps = struct.unpack_from('<I', data, 36)[0]
        ks = struct.unpack_from('<I', data, 8)[0]
    if ps not in (2048, 4096, 8192, 16384):
        return None, f"page_size 异常: {ps}"
    if ks == 0 or ps + ks > len(data):
        return None, f"kernel_size 异常: {ks}"
    return data[ps:ps + ks], None


def find_ikconfig(kernel):
    """在内核镜像里找 IKCFG_ST ... IKCFG_ED，返回解压后的文本"""
    st = kernel.find(MAGIC_ST)
    if st < 0:
        return None, "没找到 IKCFG_ST magic（内核可能没开 CONFIG_IKCONFIG）"
    gz_start = st + len(MAGIC_ST)

    # gzip 流从 gz_start 开始，找结尾
    ed = kernel.find(MAGIC_ED, gz_start)
    if ed < 0:
        # 有些内核末尾没写 IKCFG_ED，退化为尽量往后读
        blob = kernel[gz_start:]
    else:
        blob = kernel[gz_start:ed]

    # 用 gzip 解，GzipFile 会自己找到流的结尾
    try:
        with gzip.GzipFile(fileobj=io.BytesIO(blob)) as g:
            raw = g.read()
    except Exception as e:
        return None, f"gzip 解压失败: {e}"

    try:
        text = raw.decode('utf-8')
    except UnicodeDecodeError:
        text = raw.decode('latin1')
    return text, None


def normalize_config(text):
    """整理成标准 defconfig 形式：
       - 去掉注释行（保留 # CONFIG_X is not set 这种有意义的）
       - 去重（后出现的覆盖前面的，与内核 Kconfig 行为一致）
       - 排序输出，稳定可 diff
    """
    setvals = {}
    notset = set()
    order = []

    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        # 跳过纯注释（# 开头但不是 "is not set"）
        m = re.match(r'^#\s*(CONFIG_[A-Za-z0-9_]+)\s+is not set$', line)
        if m:
            name = m.group(1)
            setvals.pop(name, None)
            notset.add(name)
            if name not in order:
                order.append(name)
            continue
        if line.startswith('#'):
            continue
        m = re.match(r'^(CONFIG_[A-Za-z0-9_]+)=(.*)$', line)
        if m:
            name, val = m.group(1), m.group(2)
            notset.discard(name)
            setvals[name] = val
            if name not in order:
                order.append(name)
            continue
        # CONFIG_X 后面直接跟值（少数情况）
        m = re.match(r'^(CONFIG_[A-Za-z0-9_]+)\s+(.*)$', line)
        if m:
            name, val = m.group(1), m.group(2)
            notset.discard(name)
            setvals[name] = val
            if name not in order:
                order.append(name)

    return setvals, notset, order


def write_defconfig(setvals, notset, order, outpath, header=None):
    lines = []
    if header:
        for h in header:
            lines.append('# ' + h)
        lines.append('')
    for name in order:
        if name in setvals:
            lines.append(f'{name}={setvals[name]}')
        elif name in notset:
            lines.append(f'# {name} is not set')
    with open(outpath, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')
    return len(lines)


# 这套方案必须存在的配置项
REQUIRED = {
    'CONFIG_KALLSYMS': 'y',
    'CONFIG_KALLSYMS_ALL': 'y',
    'CONFIG_MODULES': 'y',
}
# 必须为 n 或不存在
REQUIRED_OFF = [
    'CONFIG_MODULE_SIG_FORCE',
]

# SUSFS 需要的关键配置（patch-susfs 会自己追加，这里只做提醒）
SUSFS_KEYS = [
    'CONFIG_KSU_SUSFS_SUS_PATH',
    'CONFIG_KSU_SUSFS_SUS_MOUNT',
    'CONFIG_KSU_SUSFS_SUS_KSTAT',
    'CONFIG_KSU_SUSFS_SUS_MAP',
    'CONFIG_KSU_SUSFS_SPOOF_UNAME',
    'CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG',
    'CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS',
    'CONFIG_KSU_SUSFS_OPEN_REDIRECT',
    'CONFIG_KSU_SUSFS_ENABLE_LOG',
]


UNAME_RE = re.compile(rb'Linux version (\S+) \(([^@)\s]+)@([^)\s]+)\)[\x20-\x7e]{0,400}')
STAMP_RE = re.compile(
    rb'((?:Mon|Tue|Wed|Thu|Fri|Sat|Sun) '
    rb'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) +\d+ \d\d:\d\d:\d\d \S+ \d{4})')


def parse_uname(kernel):
    """从内核镜像里抓原厂 `Linux version ...` 串，拆成可直接用的构建变量。

    返回 (dict, err)。这是「版本串不再靠人工推断」的关键：
    值来自原厂镜像本身，而不是谁记得的一段文字。
    """
    m = UNAME_RE.search(kernel)
    if not m:
        return None, ("镜像里没找到 'Linux version ...' 串"
                      "（内核可能被压缩成 zImage，或 banner 被裁掉）")
    raw = m.group(0).split(b'\x00')[0].decode('latin1')
    release = m.group(1).decode('latin1')      # 形如 4.19.110-perf+
    user = m.group(2).decode('latin1')
    host = m.group(3).decode('latin1')
    mm = re.match(r'^(\d+)\.(\d+)\.(\d+)', release)
    if not mm:
        return None, f"release 串无法拆成 X.Y.Z: {release}"
    ts_m = STAMP_RE.search(m.group(0))
    stamp = re.sub(r'\s+', ' ', ts_m.group(1).decode('latin1')).strip() if ts_m else ""
    return {
        'uname_release': release,
        'version': mm.group(1),
        'patchlevel': mm.group(2),
        'sublevel': mm.group(3),
        'localversion': release[len(mm.group(0)):] or '',
        'user': user,
        'host': host,
        'timestamp': stamp,
        'raw': raw,
    }, None


def audit(setvals, notset):
    """检查这份 config 能不能支撑我们的方案"""
    problems = []
    warnings = []

    for k, want in REQUIRED.items():
        got = setvals.get(k)
        if got != want:
            problems.append(f'{k} = {got!r}，需要 = {want}')

    for k in REQUIRED_OFF:
        if k in setvals:
            problems.append(f'{k} = {setvals[k]!r}，必须关掉（否则 vendor 模块拒载）')

    # 版本相关
    if setvals.get('CONFIG_LOCALVERSION_AUTO') == 'y':
        warnings.append('CONFIG_LOCALVERSION_AUTO=y，会让内核版本串带上 git 后缀，建议关掉')
    lv = setvals.get('CONFIG_LOCALVERSION', '')
    if 'perf+' not in lv:
        warnings.append(f'CONFIG_LOCALVERSION={lv}，原厂是 "-perf+"，不一致会影响版本伪装')

    # 模块签名
    if setvals.get('CONFIG_MODULE_SIG') == 'y':
        warnings.append('CONFIG_MODULE_SIG=y，构建脚本会追加 =n 覆盖')

    # IKCONFIG 本身
    if setvals.get('CONFIG_IKCONFIG') != 'y':
        warnings.append('CONFIG_IKCONFIG 不是 y（但既然能提出来，应该没问题）')

    return problems, warnings


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    src = sys.argv[1]
    if not os.path.isfile(src):
        print(f"[FATAL] 文件不存在: {src}")
        return 2

    outpath = None
    check_only = '--check' in sys.argv
    want_uname = '--uname' in sys.argv
    emit_env = '--env' in sys.argv
    # --env 模式下 stdout 只能有 KEY=VALUE（会被 $GITHUB_ENV 或 shell source），
    # 其它诊断信息一律走 stderr。
    log = (lambda *a, **k: print(*a, file=sys.stderr, **k)) if emit_env else print
    for i, a in enumerate(sys.argv):
        if a in ('-o', '--out') and i + 1 < len(sys.argv):
            outpath = sys.argv[i + 1]

    with open(src, 'rb') as f:
        data = f.read()

    log(f"输入: {src}  ({len(data):,} 字节)")

    # 判断是 boot.img 还是裸 kernel
    if data[:8] == BOOT_MAGIC:
        log("类型: Android boot image")
        kernel, err = extract_kernel_from_boot(data)
        if err:
            print(f"[FATAL] {err}")
            return 1
        log(f"      kernel 段: {len(kernel):,} 字节")
    else:
        # 裸 kernel：检查 arm64 magic
        log("类型: 按裸内核镜像处理")
        kernel = data
        if len(kernel) > 0x40:
            magic = struct.unpack_from('<I', kernel, 0x38)[0]
            if magic == 0x644d5241:
                log("      arm64 Image magic 正确")
            else:
                log(f"      [!] offset 0x38 不是 ARM\\x64 magic（0x{magic:08x}），可能不是内核")

    if want_uname:
        info, uerr = parse_uname(kernel)
        if uerr:
            print(f"[FATAL] {uerr}", file=sys.stderr)
            return 1
        pairs = [
            ('STOCK_UNAME_RELEASE', info['uname_release']),
            ('STOCK_VERSION', info['version']),
            ('STOCK_PATCHLEVEL', info['patchlevel']),
            ('STOCK_SUBLEVEL', info['sublevel']),
            ('STOCK_LOCALVERSION', info['localversion']),
            ('STOCK_BUILD_USER', info['user']),
            ('STOCK_BUILD_HOST', info['host']),
            ('STOCK_BUILD_TIMESTAMP', info['timestamp']),
        ]
        if emit_env:
            # --env 模式必须**只**输出 KEY=VALUE：这份输出会直接进 $GITHUB_ENV
            # 或被 shell `source`，掺任何标题行都会破坏解析。
            for k, v in pairs:
                if v:
                    print(f"{k}={v}")
            if not info['timestamp']:
                print("[WARN] 没解析到编译时间戳，KBUILD_BUILD_TIMESTAMP 需走兜底值",
                      file=sys.stderr)
            return 0
        print("=== 原厂版本串（读自镜像本身）===")
        print(f"  raw            : {info['raw']}")
        for k, v in pairs:
            print(f"  {k:20s} : {v!r}")
        if not info['timestamp']:
            print("[WARN] 没解析到编译时间戳，KBUILD_BUILD_TIMESTAMP 需走兜底值")
        return 0

    text, err = find_ikconfig(kernel)
    if err:
        print(f"[FATAL] {err}")
        print()
        print("可能原因：")
        print("  1. 内核没开 CONFIG_IKCONFIG（原厂一般会开）")
        print("  2. boot.img 的 kernel 段被压缩了（zImage 而非 Image）")
        print("  3. 拿到的不是 boot.img")
        return 1

    setvals, notset, order = normalize_config(text)
    print(f"      提取到 {len(order)} 个 CONFIG 项（其中 =y/set 的 {len(setvals)} 个）")
    print()

    problems, warnings = audit(setvals, notset)

    print("=== 关键项检查 ===")
    for k in ['CONFIG_KALLSYMS', 'CONFIG_KALLSYMS_ALL', 'CONFIG_MODULES',
              'CONFIG_MODULE_SIG', 'CONFIG_MODULE_SIG_FORCE',
              'CONFIG_MODULE_FORCE_LOAD', 'CONFIG_LOCALVERSION',
              'CONFIG_LOCALVERSION_AUTO', 'CONFIG_IKCONFIG']:
        if k in setvals:
            print(f"  {k} = {setvals[k]}")
        elif k in notset:
            print(f"  # {k} is not set")
        else:
            print(f"  {k}  (未出现)")

    if problems:
        print()
        print("=== 必须修的项 ===")
        for p in problems:
            print(f"  ✗ {p}")
    if warnings:
        print()
        print("=== 提醒 ===")
        for w in warnings:
            print(f"  ! {w}")

    print()
    print("=== SUSFS 配置项（构建脚本会自动追加，原厂一般没有）===")
    for k in SUSFS_KEYS:
        state = 'y' if setvals.get(k) == 'y' else ('n' if k in notset else '未出现')
        print(f"  {k:48s} {state}")

    if check_only:
        print()
        print("[--check] 未写文件")
        return 0 if not problems else 1

    if not outpath:
        outpath = os.path.splitext(os.path.basename(src))[0] + '_defconfig'

    header = [
        'Extracted from stock boot.img by ikconfig.py',
        f'Source: {os.path.basename(src)}',
        'Target: OnePlus 8T (kebab) / 4.19.110-perf+ / A11',
        '',
        'Used by NonGKI_Kernel_Build_2nd via DEFCONFIG_NAME',
        'Put this file at: arch/arm64/configs/vendor/kebab_defconfig',
    ]
    n = write_defconfig(setvals, notset, order, outpath, header)
    print()
    print(f"已写出: {outpath}  ({n} 行)")
    return 0 if not problems else 1


if __name__ == '__main__':
    sys.exit(main())
