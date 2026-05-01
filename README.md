# Billy

原生 Swift 桌面宠物应用，不依赖 Xcode 工程，也不依赖 Electron 下载运行时。

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

- [build/Billy.app](/Users/gongdongjie/learn1/native-swift/build/Billy.app)

## 打包 DMG

```bash
cd native-swift
./package-dmg.sh
```

会生成：

- [build/Billy.dmg](/Users/gongdongjie/learn1/native-swift/build/Billy.dmg)

## 功能

- 透明悬浮窗口
- 全屏透明窗口内活动，只在猫附近接收鼠标事件
- 自动发呆、甩尾巴、水平散步、舔爪洗脸、睡觉
- 左键单击可让行走中的猫停下
- 左键双击会驱赶它向远处走开
- 左键拖动可在接近全屏范围内换位置
- 右键菜单支持：自动散步、发呆、甩尾巴、舔爪洗脸、睡觉、退出

## 说明

当前代码层已经移除自动说话和“回窝”入口。素材会在后续阶段全部重新生成。

如果你后面给我你家猫的几张照片，我可以继续把这一版改成：

- 读取你家猫的 PNG 动作帧
- 做成更像图里那种 2D 桌宠
- 再补充喂食、待办提醒等状态
