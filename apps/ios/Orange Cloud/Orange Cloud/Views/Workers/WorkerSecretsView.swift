<path>orange-cloud/apps/ios/Orange Cloud/Orange Cloud/Views/Workers/WorkerSecretsView.swift</path>
<type>file</type>
<content>
1: //
2: //  WorkerSecretsView.swift
3: //  Orange Cloud
4: //
5: //  Worker 密钥（secret_text）+ 环境变量（plain_text）管理 + 只读绑定清单。
6: //  写操作按 workers-scripts.write 门控；改任一变量都整组回写（其余 inherit），不丢既有绑定。
7: //
8: 
9: import SwiftUI
10: import Perception
11: 
12: struct WorkerSecretsView: View {
13: 
14:     @Environment(AuthManager.self) private var auth
15:     @State private var viewModel: WorkerBindingsViewModel
16:     @State private var sheet: EditorSheet?
17:     @State private var secretToDelete: WorkerSecret?
18:     @State private var variableToDelete: WorkerBinding?
19:     @State private var bindingToUnbind: WorkerBinding?
20: 
21:     init(accountId: String, scriptName: String, session: SessionStore) {
22:         _viewModel = State(initialValue: WorkerBindingsViewModel(
23:             service: session.workerService, d1Service: session.d1Service, kvService: session.kvService,
24:             r2Service: session.r2Service, accountId: accountId, scriptName: scriptName
25:         ))
26:     }
27: 
28:     private var canWrite:   Bool { auth.hasScope("workers-scripts.write") }
29:     private var canReadD1:  Bool { auth.hasScope("d1.read") }
30:     private var canReadKV:  Bool { auth.hasScope("workers-kv-storage.read") }
31:     private var canReadR2:  Bool { auth.hasScope("workers-r2.read") }
32:     /// 能读到至少一类资源才提供快速绑定入口
33:     private var canBind:    Bool { canWrite && (canReadD1 || canReadKV || canReadR2) }
34: 
35:     var body: some View {
36:         coreContent
37:             .modifier(WorkerSecretsDialogs(
38:                 secretTitle: secretDeleteTitle,
39:                 secretPresented: secretDeleteBinding,
40:                 onDeleteSecret: deleteSecretAction,
41:                 variableTitle: variableDeleteTitle,
42:                 variablePresented: variableDeleteBinding,
43:                 onDeleteVariable: deleteVariableAction,
44:                 bindTitle: bindingUnbindTitle,
45:                 bindPresented: bindingUnbindBinding,
46:                 onUnbind: unbindAction
47:             ))
48:             .background { SkyBackground() }
49:             .navigationTitle("变量与密钥")
50:             .navigationBarTitleDisplayMode(.inline)
51:             .toolbar { toolbarContent }
52:             .task { if !viewModel.loaded { await viewModel.load() } }
53:             .sheet(item: $sheet) { kind in sheetContent(kind) }
54:             .alert("出错了", isPresented: alertBinding) {
55:                 apiErrorDocButton(for: viewModel.error)
56:                 Button("好", role: .cancel) {}
57:             } message: {
58:                 Text(viewModel.error ?? "")
59:             }
60:     }
61: 
62:     private var secretDeleteTitle: String {
63:         if let s = secretToDelete { return "删除密钥「\(s.name)」？" }
64:         return ""
65:     }
66:     private var variableDeleteTitle: String {
67:         if let v = variableToDelete { return "删除变量「\(v.name)」？" }
68:         return ""
69:     }
70:     private var bindingUnbindTitle: String {
71:         if let b = bindingToUnbind { return "解除绑定「\(b.name)」？" }
72:         return ""
73:     }
74:     private var secretDeleteBinding: Binding<Bool> {
75:         Binding(get: { secretToDelete != nil }, set: { if !$0 { secretToDelete = nil } })
76:     }
77:     private var variableDeleteBinding: Binding<Bool> {
78:         Binding(get: { variableToDelete != nil }, set: { if !$0 { variableToDelete = nil } })
79:     }
80:     private var bindingUnbindBinding: Binding<Bool> {
81:         Binding(get: { bindingToUnbind != nil }, set: { if !$0 { bindingToUnbind = nil } })
82:     }
83:     private func deleteSecretAction() {
84:         if let s = secretToDelete { Task { await viewModel.deleteSecret(s) } }
85:     }
86:     private func deleteVariableAction() {
87:         if let v = variableToDelete { Task { await viewModel.deleteVariable(v) } }
88:     }
89:     private func unbindAction() {
90:         if let b = bindingToUnbind { Task { await viewModel.unbindResource(b) } }
91:     }
92: 
93:     private var alertBinding: Binding<Bool> {
94:         Binding(
95:             get: { viewModel.error != nil && sheet == nil },
96:             set: { if !$0 { viewModel.error = nil } }
97:         )
98:     }
99: 
100:     @ViewBuilder
101:     private var coreContent: some View {
102:         if !viewModel.loaded && viewModel.isLoading {
103:             SkeletonList(rows: 5, icon: .none, trailing: true)
104:         } else {
105:             List {
106:                 secretsSection
107:                 variablesSection
108:                 if !viewModel.otherBindings.isEmpty || canBind {
109:                     otherSection
110:                 }
111:             }
112:             .scrollContentBackground(.hidden)
113:             .refreshable { await viewModel.load() }
114:         }
115:     }
116: 
117:     @ToolbarContentBuilder
118:     private var toolbarContent: some ToolbarContent {
119:         if canWrite {
120:             ToolbarItem(placement: .topBarTrailing) {
121:                 Button("批量导入 JSON", systemImage: "arrow.down.doc") {
122:                     sheet = .bulkImport
123:                 }
124:             }
125:         }
126:     }
127: 
128:     @ViewBuilder
129:     private func sheetContent(_ kind: EditorSheet) -> some View {
130:         switch kind {
131:         case .bulkImport:
132:             WorkerBulkImportSheet(viewModel: viewModel)
133:         case .bindResource:
134:             WorkerBindResourceSheet(viewModel: viewModel, canReadD1: canReadD1, canReadKV: canReadKV, canReadR2: canReadR2)
135:         default:
136:             WorkerValueEditorSheet(kind: kind, viewModel: viewModel)
137:         }
138:     }
139: 
140:     // MARK: - 密钥
141: 
142:     private var secretsSection: some View {
143:         Section {
144:             if viewModel.secrets.isEmpty {
145:                 Text("暂无密钥").font(.callout).foregroundStyle(.secondary)
146:             } else {
147:                 ForEach(viewModel.secrets) { secret in
148:                     HStack(spacing: 12) {
149:                         TintIcon(systemImage: "key.fill", color: .ocOrange)
150:                         Text(secret.name).font(.callout.weight(.medium))
151:                         Spacer()
152:                     }
153:                     .swipeActions(edge: .trailing) {
154:                         if canWrite {
155:                             Button("删除", role: .destructive) {
156:                                 secretToDelete = secret
157:                             }
158:                         }
159:                     }
160:                 }
161:             }
162:             if canWrite {
163:                 Button {
164:                     sheet = .secret
165:                 } label: {
166:                     Label("添加密钥", systemImage: "plus")
167:                 }
168:             }
169:         } header: {
170:             Text("密钥")
171:         } footer: {
172:             Text(canWrite
173:                  ? String(localized: "密钥值出于安全无法读取，列表只显示名称。同名添加即覆盖。")
174:                  : String(localized: "当前授权仅可查看（缺少 workers-scripts.write）。"))
175:         }
176:         .glassRow()
177:     }
178: 
179:     // MARK: - 环境变量
180: 
181:     private var variablesSection: some View {
182:         Section {
183:             if viewModel.variables.isEmpty {
184:                 Text("暂无变量").font(.callout).foregroundStyle(.secondary)
185:             } else {
186:                 ForEach(viewModel.variables) { binding in
187:                     Button {
188:                         if canWrite { sheet = .variable(binding) }
189:                     } label: {
190:                         HStack(spacing: 12) {
191:                             TintIcon(systemImage: "textformat", color: .ocOrange)
192:                             VStack(alignment: .leading, spacing: 2) {
193:                                 Text(binding.name).font(.callout.weight(.medium)).foregroundStyle(.primary)
194:                                 Text(binding.text ?? "")
195:                                     .font(.caption.monospaced())
196:                                     .foregroundStyle(.secondary)
197:                                     .lineLimit(1)
198:                             }
199:                             Spacer()
200:                             if canWrite {
201:                                 Image(systemName: "chevron.right")
202:                                     .font(.caption.weight(.semibold))
203:                                     .foregroundStyle(.tertiary)
204:                             }
205:                         }
206:                     }
207:                     .disabled(!canWrite)
208:                     .swipeActions(edge: .trailing) {
209:                         if canWrite {
210:                             Button("删除", role: .destructive) {
211:                                 variableToDelete = binding
212:                             }
213:                         }
214:                     }
215:                 }
216:             }
217:             if canWrite {
218:                 Button {
219:                     sheet = .variable(nil)
220:                 } label: {
221:                     Label("添加变量", systemImage: "plus")
222:                 }
223:             }
224:         } header: {
225:             Text("环境变量")
226:         } footer: {
227:             Text("明文变量（plain_text），可读可改。改任一项不影响其它绑定。")
228:         }
229:         .glassRow()
230:     }
231: 
232:     // MARK: - 资源绑定（D1 / KV 可增删，其余只读）
233: 
234:     private var otherSection: some View {
235:         Section {
236:             if viewModel.otherBindings.isEmpty {
237:                 Text("暂无资源绑定").font(.callout).foregroundStyle(.secondary)
238:             } else {
239:                 ForEach(viewModel.otherBindings) { binding in
240:                     HStack(spacing: 12) {
241:                         TintIcon(systemImage: binding.isQuickManaged ? "cube.fill" : "cube",
242:                                  color: binding.isQuickManaged ? .ocOrange : .gray)
243:                         Text(binding.name).font(.callout)
244:                         Spacer()
245:                         Text(binding.typeLabel).font(.caption).foregroundStyle(.secondary)
246:                     }
247:                     .swipeActions(edge: .trailing) {
248:                         if canWrite && binding.isQuickManaged {
249:                             Button("解除", role: .destructive) {
250:                                 bindingToUnbind = binding
251:                             }
252:                         }
253:                     }
254:                 }
255:             }
256:             if canBind {
257:                 Button {
258:                     sheet = .bindResource
259:                 } label: {
260:                     Label("绑定 D1 / KV / R2", systemImage: "plus")
261:                 }
262:             }
263:         } header: {
264:             Text("资源绑定")
265:         } footer: {
266:             Text(canBind
267:                  ? String(localized: "可绑定既有 D1 数据库 / KV 命名空间 / R2 存储桶；队列、Durable Object 等其它资源仍为只读，请用 Wrangler 或 Dashboard。")
268:                  : String(localized: "KV / D1 / R2 等资源绑定在此查看，编辑请用 Wrangler 或 Dashboard。"))
269:         }
270:         .glassRow()
271:     }
272: }
273: 
274: // MARK: - 添加/编辑弹窗
275: 
276: /// 弹窗类型：新增密钥 / 新增或编辑变量（编辑时锁定名称）/ 批量导入 JSON
277: private enum EditorSheet: Identifiable {
278:     case secret
279:     case variable(WorkerBinding?)
280:     case bulkImport
281:     case bindResource
282: 
283:     var id: String {
284:         switch self {
285:         case .secret:            "secret"
286:         case .variable(let b):   "var-\(b?.name ?? "new")"
287:         case .bulkImport:        "bulk"
288:         case .bindResource:      "bind"
289:         }
290:     }
291: }
292: 
293: private struct WorkerValueEditorSheet: View {
294: 
295:     let kind: EditorSheet
296:     let viewModel: WorkerBindingsViewModel
297: 
298:     @Environment(\.dismiss) private var dismiss
299:     @State private var name = ""
300:     @State private var value = ""
301: 
302:     private var isSecret: Bool { if case .secret = kind { return true }; return false }
303: 
304:     /// 编辑既有变量时锁定名称
305:     private var lockedName: String? {
306:         if case .variable(let binding) = kind, let binding { return binding.name }
307:         return nil
308:     }
309: 
310:     private var nameValid: Bool {
311:         let target = lockedName ?? name
312:         return target.range(of: "^[A-Za-z_][A-Za-z0-9_]*$", options: .regularExpression) != nil
313:     }
314: 
315:     private var canSave: Bool {
316:         nameValid && !value.isEmpty && !viewModel.isSaving
317:     }
318: 
319:     private var title: String {
320:         if isSecret { return String(localized: "添加密钥") }
321:         return lockedName == nil ? String(localized: "添加变量") : String(localized: "编辑变量")
322:     }
323: 
324:     var body: some View {
325:         NavigationStack {
326:             Form {
327:                 Section {
328:                     if let lockedName {
329:                         Text(lockedName).font(.callout.monospaced()).foregroundStyle(.secondary)
330:                     } else {
331:                         TextField("NAME", text: $name)
332:                             .font(.callout.monospaced())
333:                             .textInputAutocapitalization(.characters)
334:                             .autocorrectionDisabled()
335:                     }
336:                 } header: {
337:                     Text("名称")
338:                 } footer: {
339:                     if lockedName == nil {
340:                         Text("字母、数字、下划线，且不以数字开头。")
341:                     }
342:                 }
343: 
344:                 Section {
345:                     if isSecret {
346:                         SecureField("值", text: $value)
347:                             .font(.callout.monospaced())
348:                             .textInputAutocapitalization(.never)
349:                             .autocorrectionDisabled()
350:                     } else {
351:                         TextField("值", text: $value, axis: .vertical)
352:                             .font(.callout.monospaced())
353:                             .textInputAutocapitalization(.never)
354:                             .autocorrectionDisabled()
355:                             .lineLimit(1...6)
356:                     }
357:                 } header: {
358:                     Text(isSecret ? String(localized: "值（保存后不可读取）") : String(localized: "值"))
359:                 }
360: 
361:                 if let error = viewModel.error {
362:                     Section { Text(error).font(.footnote).foregroundStyle(.red) }
363:                 }
364:             }
365:             .navigationTitle(title)
366:             .navigationBarTitleDisplayMode(.inline)
367:             .toolbar {
368:                 ToolbarItem(placement: .cancellationAction) {
369:                     Button("取消") { dismiss() }
370:                 }
371:                 ToolbarItem(placement: .confirmationAction) {
372:                     Button {
373:                         Task { await save() }
374:                     } label: {
375:                         if viewModel.isSaving { ProgressView() } else { Text("保存").fontWeight(.semibold) }
376:                     }
377:                     .disabled(!canSave)
378:                 }
379:             }
380:             .interactiveDismissDisabled(viewModel.isSaving)
381:             .onAppear {
382:                 if case .variable(let binding) = kind, let binding {
383:                     value = binding.text ?? ""
384:                 }
385:             }
386:         }
387:     }
388: 
389:     private func save() async {
390:         viewModel.error = nil
391:         let ok: Bool
392:         if isSecret {
393:             ok = await viewModel.addSecret(name: name, text: value)
394:         } else {
395:             ok = await viewModel.setVariable(name: lockedName ?? name, value: value)
396:         }
397:         if ok { dismiss() }
398:     }
399: }
400: 
401: // MARK: - 批量导入 JSON
402: 
403: /// 导入目标：粘贴的 JSON 键值对作为变量或密钥写入
404: private enum BulkImportTarget: String, CaseIterable, Identifiable {
405:     case variable, secret
406:     var id: String { rawValue }
407:     var label: LocalizedStringKey { self == .variable ? "变量" : "密钥" }
408: }
409: 
410: /// 解析失败原因（携带可读信息，供 Result 使用）
411: private struct BulkParseError: Error {
412:     let message: String
413: }
414: 
415: private struct WorkerBulkImportSheet: View {
416: 
417:     let viewModel: WorkerBindingsViewModel
418: 
419:     @Environment(\.dismiss) private var dismiss
420:     @State private var target: BulkImportTarget = .variable
421:     @State private var jsonText = ""
422: 
423:     /// 解析结果：成功给出 (name, value) 列表，失败给出可读错误
424:     private var parsed: Result<[(name: String, value: String)], BulkParseError> {
425:         Self.parse(jsonText)
426:     }
427: 
428:     private var pairs: [(name: String, value: String)] {
429:         if case .success(let p) = parsed { return p }
430:         return []
431:     }
432: 
433:     private var parseError: String? {
434:         if case .failure(let e) = parsed { return e.message }
435:         return nil
436:     }
437: 
438:     private var hasInput: Bool {
439:         !jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
440:     }
441: 
442:     private var canImport: Bool { !pairs.isEmpty && !viewModel.isSaving }
443: 
444:     var body: some View {
445:         NavigationStack {
446:             Form {
447:                 Section {
448:                     Picker("导入为", selection: $target) {
449:                         ForEach(BulkImportTarget.allCases) { Text($0.label).tag($0) }
450:                     }
451:                     .pickerStyle(.segmented)
452:                 } footer: {
453:                     Text(target == .secret
454:                          ? String(localized: "作为密钥一次性写入；同名将被覆盖，保存后不可读取。")
455:                          : String(localized: "作为明文变量一次性写入；同名将被覆盖，不影响其它绑定。"))
456:                 }
457: 
458:                 Section {
459:                     TextEditor(text: $jsonText)
460:                         .font(.callout.monospaced())
461:                         .textInputAutocapitalization(.never)
462:                         .autocorrectionDisabled()
463:                         .frame(minHeight: 180)
464:                 } header: {
465:                     Text("JSON")
466:                 } footer: {
467:                     Text("粘贴一个 JSON 对象，键为名称、值为字符串或数字，例如：\n{\n  \"API_KEY\": \"abc123\",\n  \"MAX_RETRY\": 3\n}")
468:                 }
469: 
470:                 if hasInput, let parseError {
471:                     Section { Text(parseError).font(.footnote).foregroundStyle(.red) }
472:                 } else if !pairs.isEmpty {
473:                     Section { Text("将导入 \(pairs.count) 项").font(.callout).foregroundStyle(.secondary) }
474:                 }
475: 
476:                 if let error = viewModel.error {
477:                     Section { Text(error).font(.footnote).foregroundStyle(.red) }
478:                 }
479:             }
480:             .navigationTitle("批量导入")
481:             .navigationBarTitleDisplayMode(.inline)
482:             .toolbar {
483:                 ToolbarItem(placement: .cancellationAction) {
484:                     Button("取消") { dismiss() }
485:                 }
486:                 ToolbarItem(placement: .confirmationAction) {
487:                     Button {
488:                         Task { await performImport() }
489:                     } label: {
490:                         if viewModel.isSaving { ProgressView() } else { Text("导入").fontWeight(.semibold) }
491:                     }
492:                     .disabled(!canImport)
493:                 }
494:             }
495:             .interactiveDismissDisabled(viewModel.isSaving)
496:         }
497:     }
498: 
499:     private func performImport() async {
500:         viewModel.error = nil
501:         let ok: Bool
502:         switch target {
503:         case .variable: ok = await viewModel.bulkImportVariables(pairs)
504:         case .secret:   ok = await viewModel.bulkImportSecrets(pairs)
505:         }
506:         if ok { dismiss() }
507:     }
508: 
509:     /// 解析一个扁平 JSON 对象为 (name, value) 列表。
510:     /// 键须符合环境变量命名（字母/数字/下划线，不以数字开头）；值接受字符串、数字、布尔（转字符串）。
511:     private static func parse(_ text: String) -> Result<[(name: String, value: String)], BulkParseError> {
512:         let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
513:         guard !trimmed.isEmpty else { return .success([]) }
514:         guard let data = trimmed.data(using: .utf8),
515:               let object = try? JSONSerialization.jsonObject(with: data) else {
516:             return .failure(BulkParseError(message: String(localized: "不是有效的 JSON")))
517:         }
518:         guard let dict = object as? [String: Any] else {
519:             return .failure(BulkParseError(message: String(localized: "需要一个 JSON 对象，形如 {\"KEY\": \"值\"}")))
520:         }
521:         let keyPattern = "^[A-Za-z_][A-Za-z0-9_]*$"
522:         var pairs: [(name: String, value: String)] = []
523:         var invalidKeys: [String] = []
524:         for (key, raw) in dict {
525:             guard key.range(of: keyPattern, options: .regularExpression) != nil else {
526:                 invalidKeys.append(key)
527:                 continue
528:             }
529:             let value: String
530:             if let s = raw as? String {
531:                 value = s
532:             } else if let n = raw as? NSNumber {
533:                 value = CFGetTypeID(n) == CFBooleanGetTypeID() ? (n.boolValue ? "true" : "false") : n.stringValue
534:             } else {
535:                 return .failure(BulkParseError(message: String(localized: "键「\(key)」的值必须是字符串或数字")))
536:             }
537:             pairs.append((name: key, value: value))
538:         }
539:         if !invalidKeys.isEmpty {
540:             let list = invalidKeys.sorted().joined(separator: ", ")
541:             return .failure(BulkParseError(message: String(localized: "以下名称非法（须字母 / 数字 / 下划线，且不以数字开头）：\(list)")))
542:         }
543:         return .success(pairs.sorted { $0.name < $1.name })
544:     }
545: }
546: 
547: // MARK: - 快速绑定 D1 / KV / R2
548: 
549: /// 绑定既有 D1 数据库 / KV 命名空间：选类型 → 选资源 → 填绑定变量名 → PATCH settings（其余绑定 inherit）
550: private struct WorkerBindResourceSheet: View {
551: 
552:     let viewModel: WorkerBindingsViewModel
553:     let canReadD1: Bool
554:     let canReadKV: Bool
555:     let canReadR2: Bool
556: 
557:     @Environment(\.dismiss) private var dismiss
558:     @State private var kind: ResourceKind = .kv
559:     @State private var selectedId = ""
560:     @State private var name = ""
561:     @State private var nameEditedManually = false
562: 
563:     private enum ResourceKind: String, CaseIterable, Identifiable {
564:         case kv, d1, r2
565:         var id: String { rawValue }
566:         var label: String {
567:             switch self {
568:             case .kv: "KV"
569:             case .d1: "D1"
570:             case .r2: "R2"
571:             }
572:         }
573:     }
574: 
575:     /// 仅展示有读权限的类型
576:     private var availableKinds: [ResourceKind] {
577:         var kinds: [ResourceKind] = []
578:         if canReadKV { kinds.append(.kv) }
579:         if canReadD1 { kinds.append(.d1) }
580:         if canReadR2 { kinds.append(.r2) }
581:         return kinds
582:     }
583: 
584:     /// 当前类型下可选资源：(id, 显示名)。R2 按桶名引用，故 id 即桶名。
585:     private var options: [(id: String, title: String)] {
586:         switch kind {
587:         case .kv: viewModel.kvNamespaces.map { ($0.id, $0.title) }
588:         case .d1: viewModel.d1Databases.map { ($0.uuid, $0.name) }
589:         case .r2: viewModel.r2Buckets.map { ($0.name, $0.name) }
590:         }
591:     }
592: 
593:     /// 无可选资源时的空态文案
594:     private var emptyText: String {
595:         switch kind {
596:         case .kv: String(localized: "该账号暂无 KV 命名空间")
597:         case .d1: String(localized: "该账号暂无 D1 数据库")
598:         case .r2: String(localized: "该账号暂无 R2 存储桶")
599:         }
600:     }
601: 
602:     /// 资源选择器行标题
603:     private var pickerLabel: String {
604:         switch kind {
605:         case .kv: String(localized: "命名空间")
606:         case .d1: String(localized: "数据库")
607:         case .r2: String(localized: "存储桶")
608:         }
609:     }
610: 
611:     /// 资源选择区段头
612:     private var sectionHeader: String {
613:         switch kind {
614:         case .kv: String(localized: "KV 命名空间")
615:         case .d1: String(localized: "D1 数据库")
616:         case .r2: String(localized: "R2 存储桶")
617:         }
618:     }
619: 
620:     private var nameValid: Bool {
621:         name.range(of: "^[A-Za-z_][A-Za-z0-9_]*$", options: .regularExpression) != nil
622:     }
623: 
624:     private var nameDuplicate: Bool { viewModel.boundNames.contains(name) }
625: 
626:     private var canSave: Bool {
627:         !selectedId.isEmpty && nameValid && !nameDuplicate && !viewModel.isSaving
628:     }
629: 
630:     var body: some View {
631:         NavigationStack {
632:             Form {
633:                 if availableKinds.count > 1 {
634:                     Section {
635:                         Picker("类型", selection: $kind) {
636:                             ForEach(availableKinds) { Text($0.label).tag($0) }
637:                         }
638:                         .pickerStyle(.segmented)
639:                         .ocOnChange(of: kind) { _, _ in
640:                             selectedId = ""
641:                             if !nameEditedManually { name = "" }
642:                         }
643:                     }
644:                 }
645: 
646:                 Section {
647:                     if viewModel.loadingResources && options.isEmpty {
648:                         HStack { ProgressView(); Text("加载中…").foregroundStyle(.secondary) }
649:                     } else if options.isEmpty {
650:                         Text(emptyText).font(.callout).foregroundStyle(.secondary)
651:                     } else {
652:                         Picker(pickerLabel, selection: $selectedId) {
653:                             Text("请选择").tag("")
654:                             ForEach(options, id: \.id) { option in
655:                                 Text(option.title).tag(option.id)
656:                             }
657:                         }
658:                     }
659:                 } header: {
660:                     Text(sectionHeader)
661:                 }
662: 
663:                 Section {
664:                     TextField("BINDING_NAME", text: $name)
665:                         .font(.callout.monospaced())
666:                         .textInputAutocapitalization(.characters)
667:                         .autocorrectionDisabled()
668:                         .ocOnChange(of: name) { _, _ in nameEditedManually = true }
669:                 } header: {
670:                     Text("绑定变量名")
671:                 } footer: {
672:                     if nameDuplicate {
673:                         Text("已存在同名绑定。").foregroundStyle(.red)
674:                     } else {
675:                         Text("代码中通过 env 访问。字母、数字、下划线，且不以数字开头。")
676:                     }
677:                 }
678: 
679:                 if let error = viewModel.error {
680:                     Section { Text(error).font(.footnote).foregroundStyle(.red) }
681:                 }
682:             }
683:             .navigationTitle("绑定 D1 / KV / R2")
684:             .navigationBarTitleDisplayMode(.inline)
685:             .toolbar {
686:                 ToolbarItem(placement: .cancellationAction) {
687:                     Button("取消") { dismiss() }
688:                 }
689:                 ToolbarItem(placement: .confirmationAction) {
690:                     Button {
691:                         Task { await save() }
692:                     } label: {
693:                         if viewModel.isSaving { ProgressView() } else { Text("绑定").fontWeight(.semibold) }
694:                     }
695:                     .disabled(!canSave)
696:                 }
697:             }
698:             .interactiveDismissDisabled(viewModel.isSaving)
699:             .task {
700:                 kind = availableKinds.first ?? .kv
701:                 await viewModel.loadResources(canReadD1: canReadD1, canReadKV: canReadKV, canReadR2: canReadR2)
702:             }
703:             .ocOnChange(of: selectedId) { _, newValue in
704:                 // 未手动改过名字时，用所选资源名推导一个合法默认绑定名
705:                 guard !nameEditedManually, !newValue.isEmpty,
706:                       let picked = options.first(where: { $0.id == newValue }) else { return }
707:                 name = Self.suggestName(from: picked.title)
708:                 nameEditedManually = false
709:             }
710:         }
711:     }
712: 
713:     private func save() async {
714:         viewModel.error = nil
715:         let resource: WorkerBindingInput = switch kind {
716:         case .kv: .kv(name: name, namespaceId: selectedId)
717:         case .d1: .d1(name: name, databaseId: selectedId)
718:         case .r2: .r2(name: name, bucketName: selectedId)   // R2 按桶名引用
719:         }
720:         if await viewModel.bindResource(resource) { dismiss() }
721:     }
722: 
723:     /// 资源名 → 合法绑定变量名（大写、非法字符转下划线、数字开头补前缀）
724:     private static func suggestName(from title: String) -> String {
725:         var s = title.uppercased().map { $0.isLetter || $0.isNumber ? $0 : "_" }
726:         if let first = s.first, first.isNumber { s.insert("_", at: s.startIndex) }
727:         let result = String(s)
728:         return result.isEmpty ? "BINDING" : result
729:     }
730: }
731: 

(End of file - total 731 lines)
</content>

/// 三个删除/解绑确认弹窗（拆出以免 body 类型检查超时）
private struct WorkerSecretsDialogs: ViewModifier {
    let secretTitle: String
    let secretPresented: Binding<Bool>
    let onDeleteSecret: () -> Void
    let variableTitle: String
    let variablePresented: Binding<Bool>
    let onDeleteVariable: () -> Void
    let bindTitle: String
    let bindPresented: Binding<Bool>
    let onUnbind: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(secretTitle, isPresented: secretPresented, titleVisibility: .visible) {
                Button("删除", role: .destructive) { onDeleteSecret() }
            } message: {
                Text("密钥值无法读回，删除后需重新设置，不可撤销。")
            }
            .confirmationDialog(variableTitle, isPresented: variablePresented, titleVisibility: .visible) {
                Button("删除", role: .destructive) { onDeleteVariable() }
            }
            .confirmationDialog(bindTitle, isPresented: bindPresented, titleVisibility: .visible) {
                Button("解除绑定", role: .destructive) { onUnbind() }
            } message: {
                Text("仅解除该 Worker 与此资源的绑定，不会删除资源本身。")
            }
    }
}
