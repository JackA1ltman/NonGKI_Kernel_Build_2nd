| Device | Location | Codename | Kernel/Author/Name | OS | Android | Pack Method | KernelSU | SuSFS | Hook | KPM | Re:Kernel | Status |  
|---|---|---|---|---|---|---|---|---|---|---|---|---|  
| Oneplus 8 | All | instantnoodle | [4.19/ppajda/XTD](https://github.com/ppajda/android_kernel_oneplus_sm8250) | Oxygen OS 13.1 | 13 | AnyKernel3 | Magic | ✅ | Normal | ❌ | ❌ | Stable |  
| Xiaomi Mix2s | All | polaris | [4.9/Evolution-X-Devices/sdm845](https://github.com/Evolution-X-Devices/kernel_xiaomi_sdm845) | Evolution X 10.X | 15 | AnyKernel3 | SukiSU(U) | ✅ | Tracepoint | ✅ | ✅ | Stable |  
| Xiaomi 11 Ultra | All | star | [5.4/EndCredits/Acetaminophen](https://github.com/EndCredits/android_kernel_xiaomi_sm8350-miui) | HyperOS | 14 | Anykernel3 | rsuntk | ✅ | Normal | ❌ | ❌ | Stable |  
| Redmi K20 Pro | All | raphael | [4.14/SOVIET-ANDROID/SOVIET-STAR-OSS](https://github.com/SOVIET-ANDROID/kernel_xiaomi_raphael) | Based-AOSP | 15 | AnyKernel3 | rsuntk | ✅ | Syscall | ❌ | ❌ | Stable |  

**English**:  
- OnePlus 8 OxygenOS/ColorOS 13.1 has been tested and can be used on the OnePlus 8, 8T, 8 Pro and 9R.
- Xiaomi Mix 2S EvolutionX 10 has been backported to Cgroup V2, but Cgroup Freezer requires additional system steps to be used and the actual execution of the freezing process is abnormal. It is recommended to use Cgroup UID.

**Chinese**:  
- 一加 8 OxygenOS/ColorOS 13.1 经测试8、8T、8 Pro、9R 都可用
- 小米 Mix2s EvolutionX 10 已移植Cgroup V2，但Cgroup Freezer需要依赖系统额外步骤才能使用且该功能实际执行冻结过程异常，建议使用Cgroup UID
