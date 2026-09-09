# Privacy / 隐私

## English

knock-knock reads calendars through macOS EventKit after you grant access. Apple's full-access permission is required to read events on supported macOS versions; the app does not create, edit, or delete events.

Event titles, dates, locations, calendar names, and detected meeting links are processed in memory to display upcoming events and reminders. Event notes may be inspected in memory to find a meeting link. Local preferences store settings, excluded calendar identifiers, and event identifiers with delivery or snooze timestamps. Delivery history is pruned after seven days during refresh. The app does not keep its own database of event titles or notes.

There is no app backend, account system, analytics SDK, advertising, automatic updater, or calendar upload code. Opening a meeting link launches your browser or meeting app; that app's privacy policy applies. Your calendar provider's synchronization and macOS diagnostics are outside knock-knock's control.

Reminders intentionally display event information on screen. Consider other people nearby and screen sharing when choosing to run reminders; the app does not automatically detect screen sharing. You can pause reminders in the app. macOS Calendar permission can be revoked in System Settings. To remove locally saved preferences after quitting, run `defaults delete app.knockknock.mac` in Terminal. This does not delete events from Calendar.

### Public repository and release

- The public project begins with a clean history of selected source and assets. Local working folders, preferences, calendar exports, and earlier screenshots are excluded.
- Product PNGs come from `Tests/RenderPreviews.swift`, which supplies fictional events and calendars in a separate test bundle. It never starts monitoring or requests access. PNG metadata is removed by `scripts/product-images.py`.
- The logo, sprites, and sounds are original project assets. There are no external stock-image credits or embedded personal profiles.
- Release binaries use neutral source-path prefixes and stripped debug symbols. The DMG contains the app, an Applications shortcut, installation instructions, and the MIT license.
- Git commits use the publisher's public GitHub handle and GitHub noreply address. These are intentional public attribution; no private email address is needed.

Please do not include private calendar data, access tokens, or unredacted desktop screenshots in public issues or pull requests.

## 简体中文

knock-knock 在获得授权后，通过 macOS EventKit 读取日历。在支持的 macOS 版本上，读取日程需要系统的完整访问权限；应用不会创建、修改或删除日程。

日程标题、时间、地点、日历名称及识别到的会议链接在内存中处理，用于展示日程和提醒。应用可能在内存中检查日程备注以寻找会议链接。本地偏好设置保存应用设置、被排除的日历标识，以及带有提醒或稍后提醒时间的日程标识；刷新时会清理超过七天的已提醒记录。应用不建立存储日程标题或备注的独立数据库。

应用没有后端、账户系统、分析 SDK、广告、自动更新器或日历上传代码。点击会议链接会打开浏览器或会议应用，后续行为适用该应用的隐私政策。日历服务商的同步以及 macOS 的系统诊断不由 knock-knock 控制。

提醒会有意在屏幕上显示日程信息。使用时请留意旁人及屏幕共享；应用不会自动检测屏幕共享。可以在应用中暂停提醒，也可以在系统设置中撤销日历权限。退出应用后，可在终端运行 `defaults delete app.knockknock.mac` 清除本地偏好设置；此操作不会删除系统日历中的日程。

### 公开仓库与安装包

- 公开项目从筛选后的源码和资源创建全新历史，不包含本地工作目录、偏好设置、日历导出或早期截图。
- 产品图片由独立测试应用中的虚构数据生成，测试不启动日历监控，也不申请日历权限。导出时移除 PNG 元数据。
- 标志、像素角色和音效均为项目原创资源，不包含个人资料。
- 发布二进制替换源码路径前缀并移除调试符号；DMG 仅包含应用、应用程序目录快捷方式、安装说明和 MIT 许可证。
- Git 提交使用发布者的公开 GitHub 用户名和 GitHub noreply 地址作为公开署名，不使用私人邮箱。

请勿在公开的问题或拉取请求中提供私人日程、访问令牌或未脱敏的桌面截图。
