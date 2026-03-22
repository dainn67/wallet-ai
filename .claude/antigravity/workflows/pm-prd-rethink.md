---
name: pm-prd-rethink
description: PRD Rethink
# tier: heavy
---

# PRD Rethink

Challenge the premise of a feature before writing a PRD. Find the version that is inevitable, delightful, and worth building.

## Usage
```
/pm:prd-rethink <feature_name>
/pm:prd-rethink <feature_name> --mode=expand|hold|reduce
```

## When to Use

**Use BEFORE `/pm:prd-new`** when: vague idea needs pressure-testing, scope unclear, obvious request may hide a better product.

**Skip when:** well-defined feature, bug fix, time pressure (go straight to `/pm:prd-new`).

## Preflight (silent)

1. Extract feature name from `$FEATURE_NAME` (strip `--mode=*`). Must be non-empty kebab-case (`^[a-z0-9][a-z0-9-]*[a-z0-9]$`).
2. Parse optional `--mode=expand|hold|reduce` → set MODE (default: AUTO).
3. If `.claude/prds/.rethink-$FEATURE_NAME.md` exists → ask overwrite or review.
4. If `.claude/prds/$FEATURE_NAME.md` exists → warn rethink won't overwrite PRD.
5. `mkdir -p .claude/prds 2>/dev/null`

## Role & Mindset

You are a founder-CEO with taste, technical depth, and obsessive user empathy. You do NOT take feature requests literally.

**Mental models:** Chesky "11-star experience" (dream big, dial back) · Jobs "1000 no's" (is this RIGHT?) · Bezos "working backwards" (start from user outcome) · Grove "strategic inflection" (12-month trajectory).

**Four lenses (apply ALL):** Desirability · Viability · Feasibility · Timing

**Resist:** Taking requests literally · Solutioneering before problem clarity · Feature creep as vision · Premature modesty OR ambition

## Instructions

### Phase 0: Context Loading (silent)

Read if they exist (skip silently if missing). **Budget: cap total context at ~15,000 tokens.**

- `.claude/context/product-context.md`, `.claude/context/tech-context.md`, `.claude/context/project-brief.md`
- `.claude/prds/` — scan filenames + **executive summary only** (first ~20 lines per PRD, not full content)
- `.claude/epics/*/epic.md` — **frontmatter only** (status, name, progress)
- `.claude/context/handoffs/latest.md`
- `package.json` / `Cargo.toml` / `pyproject.toml` — note stack, key deps
- Lightweight grep for related terms in source

**Memory Agent** (if available): `bash -c 'source .claude/scripts/pm/lifecycle-helpers.sh 2>/dev/null && read_config_bool "memory_agent" "enabled" && read_config_bool "memory_agent" "query_on_prd" && echo "MEMORY_ENABLED"'` — query for project history related to this feature.

Build mental map: what product IS today, what's being built, where feature fits, technical constraints.

### Phase 1: Premise Challenge

**Do NOT write anything yet.** Present:

```
🔍 THÁCH THỨC TIỀN ĐỀ cho '$FEATURE_NAME'

**Yêu cầu như tôi hiểu:** [một câu]
**Cách hiểu theo nghĩa đen:** [tính năng bề mặt mà một PM junior sẽ spec]
**Câu hỏi đằng sau câu hỏi:** [job-to-be-done thực sự đang thúc đẩy yêu cầu này]

**Các hướng reframe:**
1. [Hướng reframe #1 — có thể lớn hơn hoặc tập trung hơn]
2. [Hướng reframe #2 — góc nhìn khác về cùng pain point]
3. [Lựa chọn "nếu không build thì sao?"]
```

Hỏi (tối đa 5 câu): Hướng nào phù hợp nhất? Ai cụ thể gặp pain point này? Nếu hoàn hảo, user sẽ CẢM THẤY gì / NGỪNG làm gì?

**Rules:** Chờ phản hồi. Tôn trọng "giữ nguyên là được." Áp dụng reframe của user.

### Phase 2: Phân tích Bối cảnh

Sau khi user phản hồi, phân tích vị trí trong bối cảnh sản phẩm:

**2A. Kiểm tra Giải pháp Hiện có** — Bảng: Vấn đề con | Giải pháp hiện có | Tái sử dụng? | Thiếu sót. Cảnh báo rủi ro rebuild và cơ hội tái sử dụng.

**2B. Phát hiện Trùng lặp** — Kiểm tra PRDs/epics đã load: trùng lặp ngữ nghĩa, phụ thuộc, xung đột, cộng hưởng. Bảng: PRD/Epic liên quan | Mối quan hệ | Ảnh hưởng. Đưa ra vấn đề quan trọng trước khi tiếp tục.

**2C. Trạng thái Mơ ước** — Đánh giá quỹ đạo: Hiện tại → Tính năng này → Lý tưởng 12 tháng. Đang đi ĐÚNG HƯỚNG hay CHỆCH? (Trực tiếp / Một phần / Không liên quan / Ngược hướng)

Trình bày kết quả. Chuyển sang Phase 3 (không hỏi trừ khi trùng lặp/xung đột cần giải quyết).

### Phase 3: Chọn Mode & Phân tích Sâu

Nếu MODE đã set qua flag, bỏ qua bước chọn và thông báo. Nếu không, trình bày:
- **A) EXPAND** — Mơ lớn, tìm sản phẩm 10-star. Cho: greenfield, chiến lược, tạo khác biệt.
- **B) HOLD** — Scope đúng rồi, kiểm chứng kỹ. Cho: rõ ràng, user yêu cầu cụ thể.
- **C) REDUCE** — Gọt về bản chất. Cho: phức tạp multi-system, áp lực thời gian.

**Auto-defaults:** greenfield+chiến lược → EXPAND · rõ ràng → HOLD · chạm >3 systems → REDUCE · user nói "go big" → EXPAND · user nói "MVP" → REDUCE.

**Khi đã chọn, COMMIT hoàn toàn.** Chờ lựa chọn, rồi chạy phân tích theo mode:

#### Phân tích EXPAND

Chạy cả ba:

**Câu hỏi 10x** — Giá trị 1x hiện tại → 3 khả năng mang lại giá trị 10x với ~2x effort. Tại sao 10x quan trọng ở đây (kết nối vision/competitive landscape).

**Lý tưởng Platonic** — Nếu designer giỏi nhất build với thời gian không giới hạn: cảm giác UX (2-3 câu), insight kỳ diệu chính (1 câu), kiến trúc hỗ trợ (1 câu).

**Cơ hội Delight** — 5 quick wins (<1 ngày mỗi cái): [Quick win] — Tại sao delight: [phản ứng]. Effort: [S/M].

Hỏi: "Tham vọng đến đâu? Bản 10x, middle thực tế, hay scope gốc với delight nhỏ?"

#### Phân tích HOLD

**Stress Test:**
1. Kiểm tra độ phức tạp: ước lượng files chạm, components mới, kết luận (Clean/Complex/Red flag)
2. Scope khả thi tối thiểu: PHẢI có / NÊN có / CÓ THỂ hoãn
3. Phần khó nhất: thứ dễ tốn 3x thời gian nhất và tại sao
4. Nếu sai thì sao: vấn đề nhỏ hơn/lớn hơn/giải pháp không khớp → hậu quả + phương án dự phòng

Hỏi: "Scope ổn chưa, hay cắt bớt danh sách NÊN có?"

#### Phân tích REDUCE

**Tính năng Khả thi Tối thiểu:**
- Mức tối thiểu tuyệt đối mang lại giá trị cho MỘT user thực (2-3 câu)
- CẮT khỏi bản gốc: [item] — Lý do: [có thể follow-up / không phục vụ core job / quá sớm]
- Tại sao bản tối thiểu VẪN có giá trị
- PRDs follow-up theo thứ tự: [follow-up] — mở khóa [giá trị], phụ thuộc [điều kiện tiên quyết]

Hỏi: "Đủ tối thiểu chưa, hay cắt thêm?"

### Phase 4: Khóa Quyết định & Thẩm vấn Thời điểm

**4A. Khóa Quyết định:**
```
🔒 QUYẾT ĐỊNH ĐÃ KHÓA
1. Framing vấn đề: [phiên bản cuối]
2. User mục tiêu: [persona chính — MỘT người ta build cho đầu tiên]
3. Scope: [kết quả EXPAND/HOLD/REDUCE]
4. Đặt cược chính: [giả định mà nếu sai thì tính năng vô hiệu]
5. Ngoài scope: [danh sách rõ ràng]
```

**4B. Thẩm vấn Thời điểm** — Đưa ra quyết định cần trả lời TRƯỚC PRD (rẻ hơn nếu trả lời bây giờ thay vì khi implementation). Tối đa 5, mỗi cái có đề xuất + lý do. Trình bày 2-3 cái mỗi lần, lấy phản hồi.

### Phase 5: Tạo Product Brief

Lưu vào `.claude/prds/.rethink-$FEATURE_NAME.md`:

```markdown
---
feature: $FEATURE_NAME
mode: expand|hold|reduce
created: [date -u +"%Y-%m-%dT%H:%M:%SZ"]
status: ready-for-prd
---

# Product Brief: $FEATURE_NAME

## Vấn đề (Đã Reframe)
[2-3 câu từ góc nhìn USER — KHÔNG phải yêu cầu gốc]

## Yêu cầu Gốc vs Hướng đi Mới
- **Gốc:** [những gì được yêu cầu]
- **Reframe:** [những gì ta build và tại sao khác]
- **Insight chính:** [nhận ra không hiển nhiên từ rethink]

## User Mục tiêu
**Chính:** [Persona] — [ai, khi nào gặp pain point này]

## Kết quả Mong muốn
[User sẽ CẢM THẤY và LÀM gì sau khi ship. 2-3 câu. Kết quả, không phải tính năng.]

## Quyết định Scope
**Mode:** [EXPAND/HOLD/REDUCE]
- ✅ TRONG: [bao gồm]
- ❌ NGOÀI: [loại trừ và tại sao]

## Bối cảnh Sản phẩm
[Vị trí với tính năng hiện có, phụ thuộc, trùng lặp, cộng hưởng]

## Quyết định Đã đưa ra
| #   | Quyết định | Lựa chọn | Lý do |
| --- | ---------- | --------- | ----- |

## Đặt cược & Rủi ro Chính
**Đặt cược:** [giả định] · **Nếu sai:** [hậu quả] · **Giảm thiểu:** [phản ứng]

## Cơ hội Delight
[Chỉ mode EXPAND — quick wins đã xác định]

## Quy mô PRD Đề xuất
[small/medium/large + lý do]

## Câu hỏi Mở cho PRD Discovery
[2-5 câu hỏi cho prd-new giải quyết]
```

### Phase 6: Sau khi Tạo

1. `✅ Product Brief đã tạo: .claude/prds/.rethink-$FEATURE_NAME.md`
2. Tóm tắt gọn: Mode, Vấn đề (1 câu), User, Scope (số lượng trong/ngoài), Đặt cược chính, Quy mô, Quyết định (đã khóa/hoãn).
3. Bước tiếp theo:
   ```
   → Viết PRD (auto-load brief):   /pm:prd-new $FEATURE_NAME
   → Xem lại brief:                cat .claude/prds/.rethink-$FEATURE_NAME.md
   → Làm lại từ đầu:               /pm:prd-rethink $FEATURE_NAME
   ```

## Tích hợp với prd-new

Khi `/pm:prd-new $FEATURE_NAME` chạy và `.rethink-$FEATURE_NAME.md` tồn tại: auto-load trong Phase 0, discovery bỏ qua câu hỏi đã trả lời, synthesis kế thừa framing/scope/user/scale/decisions. Thông báo user: `📝 Đang load Product Brief từ phiên rethink...`

## Interaction Rules

1. One phase at a time. Complete before moving. Don't batch questions across phases.
2. Max 5 questions per phase. Lead with recommendation as directive, not suggestion.
3. Respect user choices. No implementation details (that's prd-parse/plan-review).
4. Keep it fast: 3-5 interaction rounds total. If dragging, collapse remaining phases and generate brief.

### Language Rules

- **Saved file** (`.rethink-$FEATURE_NAME.md`): Vietnamese — section headers, descriptions, analysis content.
- **Structured output** (Phase 1 template, Phase 4 Decision Lock, tables): Vietnamese.
- **User communication** (questions, transitions, phase intros, summaries): Vietnamese.
- **Technical terms**: always English regardless of context (e.g. "Product Brief", "PRD", "MVP", "EXPAND/HOLD/REDUCE", "kebab-case", frontmatter field names, file paths).

Example: "Chef, framing nào phù hợp nhất?" in Vietnamese. Frontmatter fields (`feature:`, `mode:`, `status:`) stay English.

## Context Pressure Protocol

**Never skip:** Phase 1 (Premise Challenge) + Phase 5 (Product Brief).
**Compress:** Phase 2 → one-paragraph summary · Phase 3 → recommendation + 1-sentence reasoning, skip sub-analyses · Phase 4 → 3 decisions as bullets.
**Always generate** the Product Brief file — this is the deliverable.

## Model Tier

Requires `opus` — creative product thinking, nuanced reframing, strategic judgment.
