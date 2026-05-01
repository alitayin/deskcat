# Native Swift CatBuddy

这个版本不依赖 Xcode 工程，也不依赖 Electron 下载运行时。

只用系统已有的命令行工具：

- `swiftc`
- macOS 自带 `AppKit`

## 编译

```bash
cd native-swift
./build.sh
```

## 运行

```bash
cd native-swift
./run.sh
```

会生成：

- [build/CatBuddy.app](/Users/gongdongjie/learn1/native-swift/build/CatBuddy.app)

## 功能

- 透明悬浮窗口
- 常驻屏幕底部附近
- 自动发呆、散步、睡觉
- 左键点击会说话
- 左键拖动可换位置
- 右键菜单支持：自动散步、发呆、睡觉、回窝、退出

## 说明

这个原生版先用了代码绘制的小猫，目的是绕开素材和运行时依赖，先把“桌宠壳子”跑起来。

如果你后面给我你家猫的几张照片，我可以继续把这一版改成：

- 读取你家猫的 PNG 动作帧
- 做成更像图里那种 2D 桌宠
- 再补充喂食、待办提醒、睡觉回窝这些状态
