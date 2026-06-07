# Admin Front DownloadManager Error Source Quality Spec

日期：2026-06-07

## 需求分析

【需求判断】
是真问题。`admin_front_ts/src/components/DownloadManager/src/download.ts` 在当前 source-quality inventory 里仍有两处 `catch (...: any)`，Web 下载失败后还会 `window.open(url, '_blank')` 静默兜底，用户无法知道 fetch 下载已经失败。

【核心问题】
下载边界应该把错误当成错误处理：已知的用户取消可以显式返回 `undefined`，其它下载失败必须抛出非空 `Error.message`，不能用 direct-open 掩盖失败。

【复杂度检查】
不重做下载管理器，不改 Tauri 命令，不拆 UI。只新增一个小的 error helper 文件，让 `unknown` 错误收口为明确的 `Error`，并用 Vitest source guard 防止回退。

【破坏性分析】
保留 `downloadFile(url, filename, options)` 签名、Tauri 成功下载流程、Web fetch blob 成功下载流程、用户取消返回 `undefined`。刻意改变的是 Web fetch 失败：从静默打开新窗口改成抛错；这是修复隐藏失败，不是合法降级。

## 代码分析

【数据结构】
错误边界只有两类：

- user-cancelled：由 `download.userCancelled` 文案精确匹配，返回 `undefined`
- real error：必须是 `Error` 且 message 非空，否则抛出边界错误

【特殊情况】
`catch (error: any)` 是类型结构缺失。`window.open(url, '_blank')` 在 fetch catch 内是兜底掩盖 bug：下载失败后用户看到的是新页面，而不是失败原因。

【复杂度】
新增 `errors.ts` 只放两个纯函数：

- `isDownloadUserCancelled(error, cancelMessage)`
- `requireDownloadError(error, operation)`

没有策略模式、没有下载状态机重写。

【兼容性】
不改公开导出名、不改参数、不改成功路径。只让失败路径 fail closed。

【结论】
值得做。它关闭 DownloadManager 的两个 `catch-any` 行，并删除一个真实静默兜底点。

## Acceptance

- `download.ts` 不再包含 `catch (error: any)` 或 `catch (err: any)`
- Tauri 下载 catch 使用 `unknown`，用户取消仍返回 `undefined`
- Web fetch catch 使用 `unknown`，失败后抛错，不再 `window.open(url, '_blank')`
- 新 helper 拒绝非 `Error` 或空 message 的错误原因
- targeted Vitest 与 `npm run typecheck` 通过
- source-quality inventory 刷新后 `catch(error: any)` 从 `6` 降到 `4`
