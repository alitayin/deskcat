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

脚本会先按最新代码重新编译 `build/Billy.app`，再重新生成 DMG。

每次运行都会覆盖旧的：

- [build/Billy.dmg](/Users/gongdongjie/learn1/native-swift/build/Billy.dmg)

## 功能

- 透明悬浮窗口
- 全屏透明窗口内活动，只在猫附近接收鼠标事件
- 自动发呆、观察、伸懒腰、水平散步、冲刺跑、舔爪洗脸、睡觉
- 左键单击可让行走中的猫停下
- 左键双击会驱赶它向远处走开
- 左键拖动可在接近全屏范围内换位置
- 右键菜单支持：自动散步、发呆、观察、伸懒腰、舔爪洗脸、睡觉、退出

## 动画素材

动画素材可以直接放入 `assets/pet`，按 `动作名-数字.png` 命名，例如 `daze-1.png`、`look-1.png`、`lazy-1.png`、`walk-left-1.png`、`run-1.png`。运行时会按数字顺序播放。

运行时显示尺寸和鼠标命中区域：散步和冲刺跑是 `200 x 200`，其他动作是 `160 x 160`。播放速度：散步是 `300ms/帧`，冲刺跑是头尾 `500ms/帧`、中间渐变到 `200ms/帧`，发呆和观察是 `800ms/帧`，其他动作是 `500ms/帧`。

如果需要临时从 `4x4` sprite sheet 导入，也可以使用：

```bash
cd native-swift
./import_action_4x4.sh assets/source-sheets/ai-generated/daze.png daze
```

详细规则见 [docs/SPRITE_WORKFLOW.md](/Users/gongdongjie/learn1/native-swift/docs/SPRITE_WORKFLOW.md)。

## 说明

当前代码层已经移除自动说话和“回窝”入口。素材会在后续阶段全部重新生成。

如果你后面给我你家猫的几张照片，我可以继续把这一版改成：

- 读取你家猫的 PNG 动作帧
- 做成更像图里那种 2D 桌宠
- 再补充喂食、待办提醒等状态
