<h2 align="center">Non-GKI 内核自动化编译项目</h2>

<p align="center">
  <a href="README.md">English</a> | 中文说明 | <a href="Supported_list.md">支持列表</a> | <a href="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/wiki">Wiki</a>
</p>
<p align="center">
  <img alt="GitHub Actions Workflow Status" src="https://img.shields.io/github/actions/workflow/status/JackA1ltman/NonGKI_Kernel_Build_2nd/build-release.yml?branch=mainline&style=for-the-badge"> <img alt="GitHub Downloads (all assets, latest release)" src="https://img.shields.io/github/downloads/JackA1ltman/NonGKI_Kernel_Build_2nd/latest/total?style=for-the-badge">
 <img alt="GitHub License" src="https://img.shields.io/github/license/JackA1ltman/NonGKI_Kernel_Build_2nd?style=for-the-badge">
</p>
> [!NOTE]
> **版本：2.0**  

### 简介  
本项目建立之初，目标就是为了更多**Non-GKI内核**提供相对稳定的**KernelSU**以及**SuSFS**的编译更新渠道  
同时提供更轻松的基于**Github Action**的编译渠道，不仅仅是便于我们维护，也便于您利用我们的项目编译属于自己的内核  

> [!IMPORTANT]
>我们基于[GPLv3协议](LICENSE)  
>
>我们允许
>    - Fork 并用于自行编译
>    - Star本项目
>    - 参与贡献项目
>    - 基于开源和免费提供意向的小范围编译成果分享
>
>我们不允许
>    - 利用本项目提供付费项目
>    - 未经同意进行商业行为

---

### 特性

- [x] **架构**
    - [x] 统一更新的子模块
    - [x] 相对独立的变量调用
    - [x] 不需要额外关联的变量
- [x] **模块**
    - [x] 无特殊需求无需修改子模块
    - [x] 便于理解和学习的子模块
- [x] **易用**
    - [x] 若无SuSFS需求在仅修改部分变量后就可以直接进行编译
    - [x] 本地生成SuSFS修补补丁后更容易的填写和调用补丁
    - [x] 多分支保证Fork后不再难以寻找示例YAML
- [x] **系统**
    - [x] 支持Ubuntu 20.04-24.04
    - [x] 支持Arch Linux
    - [x] 支持在X86_64下编译
    - [ ] 支持在ARM64下编译
- [x] **编译**
    - [x] 支持ARM64内核
    - [x] 支持ARM(ARMV7A)内核
    
---

### 鸣谢

- 感谢来自 [版本：1.X](https://github.com/JackA1ltman/NonGKI_Kernel_Build) 系列的贡献者（排名不分前后）:
    - [@adontoo](https://github.com/adontoo)
    - [@PeterTea5822](https://github.com/PeterTea5822)
    - [@pkczc](https://github.com/pkczc)
    - [@yu13140](https://github.com/yu13140)
- 感谢 [KernelSU_Action](https://github.com/xiaoleGun/KernelSU_Action) - @xiaoleGun 为本项目提供了诸多灵感
- 感谢每一名提供**Issue**的用户
- 感谢曾在**酷安**为本项目提供**Issue**或构思的用户

### 版权
- [KernelSU](https://github.com/tiann/KernelSU) - @tiann
    - [rsuntk](https://github.com/rsuntk/KernelSU) - @rsuntk
    - [Magic](https://github.com/backslashxx/KernelSU) - @backslashxx
    - [SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra) - @ShirkNeko
- [SuSFS](https://gitlab.com/simonpunk/susfs4ksu) - @simonpunk
- [Re:Kernel](https://github.com/Sakion-Team/Re-Kernel) - @Sakion-Team
- 以及更多的开源内核作者
