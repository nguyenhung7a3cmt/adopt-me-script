# BLAIR HUB v7.8 — MODULE SPLIT MAP
> File này là bản đồ chính xác (đã scan blairscript.txt 4514 dòng) để bất kỳ ai/AI nào
> cũng có thể tách module mà không bị lệch, không sót function, không trùng lặp.

---

## QUY TẮC CHUNG

1. **KHÔNG viết lại logic** — chỉ copy nguyên văn theo line range, giữ comment gốc.
2. **Line range tính theo file `blairscript.txt`** (bản gốc 4514 dòng, có `\r\n`).
3. Mỗi module bọc các biến/hàm cần share vào table trả về (`return M`).
4. State dùng chung giữa nhiều module → đặt ở module phụ thuộc *sớm nhất*, export ra,
   các module sau nhận qua `M.init(deps)`.
5. Sau khi xong 1 file, **đánh dấu DONE** vào bảng dưới để người/AI tiếp theo biết.
6. Nếu thấy 1 hàm dùng biến chưa thấy định nghĩa trong range của mình → ghi vào
   mục "MISSING DEPENDENCY" ở cuối file readme này, đừng tự bịa ra.

---

## BẢNG LINE RANGE THEO MODULE (đã verify từ grep)

| # | Module | Line range (blairscript.txt) | Trạng thái |
|---|--------|-------------------------------|------------|
| 1 | core.lua | 11-49 (services, C, Config, KEYBINDS, EV_MAP, EVIDENCE_INFO) + 107-111 (getMap/getItems/getZones/getChar/getBP) + 145-153 (getRemote) | ☐ TODO |
| 2 | ghost.lua | 51-52 (GHOST_DB), 56-68 (detectedEvidence + evidence state), 70-105 (detectionConns, MISS_SKIP, recordMiss/shouldSkip/resetMissCounts/markAbsent), 155-216 (loadGhostDB, playerNamesCache, findGhost, isHunting), 790-907 (updateGhostFilter→submitGuess), 933-1133 (startPassiveDetection) | ☐ TODO |
| 3 | inventory.lua | 550-763 (getInvRemote → returnTool) | ☐ TODO |
| 4 | movement.lua | 113-144 (getAllESPItemRoots — XEM LẠI, có thể thuộc esp.lua), 217-545 (moveToPos, tweenTo, getOutsidePos, openVanDoor, getSortedRooms, gaussian, smartTP, goToGhostRoom), 908-929 (goToVan) | ☐ TODO |
| 5 | esp.lua | 113-144 (getAllESPItemRoots, nếu xác nhận thuộc đây), 2219-2497 (normalizeItemName → cleanESPCache) | ☐ TODO |
| 6 | farm.lua | 764-789 (setFarmStatus, waitHuntOver, safewait), 1138-1592 (checkEMF, checkWriting, checkSLS, checkSBox), 1955-2217 (trySubmitAndGoVan, runAutoFarm) | ☐ TODO |
| 7 | quests.lua | 1598-1948 (findObjectivesFolder → doAllQuests) | ☐ TODO |
| 8 | trait.lua | 3755-4078 (TS table, addTraitLog, setTraitVisible, initTraitDetection, markTrait, hookGhostRoomLight, hookSalt) + phần item-throw/ghost-speed log nếu nằm sau dòng 4079 (XEM LẠI khi đọc 4079-4514) | ☐ TODO |
| 9 | ui.lua | 2498-2512 (applyFullBright, restoreLight — lighting, có thể để core hoặc ui), 2522-2804 (hookHRP, ensureHRPHook, enableFly, makeUnload, disableGameCameraScripts, enableGhostMode), 3020-3754 (sectionLabel → trait card UI), 4080-4513 (heartbeat loops, ESP loop, item throw hooks, cuối file) | ☐ TODO |
| 10 | main.lua | 1-9 (bootstrap: `_G.BlairHub`, destroy old UI) + load-order template | ☐ TODO |

---

## VÙNG CẦN XEM LẠI KỸ (chưa chắc 100%)

- **Dòng 113-144 (`getAllESPItemRoots`)**: nằm vật lý gần đầu file (cụm helper) nhưng
  về logic là ESP. Người tách `esp.lua` và `movement.lua`/`core.lua` cần thống nhất —
  **đề xuất: để trong `esp.lua`**, vì tên hàm + nội dung (`ESP item roots`) thuộc ESP.

- **Dòng 2498-2512 (`applyFullBright`, `restoreLight`)**: là lighting hack, dùng bởi
  toggle "Full Bright" trong UI. Có thể để trong `ui.lua` cùng phần TOOLS section,
  hoặc tách riêng — **đề xuất: để trong `ui.lua`** vì chỉ dùng 1 lần ở toggle.

- **Dòng 2219-2291**: khoảng giữa cuối `runAutoFarm` (kết thúc ~2217) và
  `normalizeItemName` (bắt đầu 2292) — kiểm tra xem có code/comment nào bị bỏ sót
  không khi tách `farm.lua` và `esp.lua`.

- **Dòng 4079-4514 (sau `hookSalt`)**: chứa `task.spawn` loops (item throw count,
  ghost speed log, vuult light count, mare consec off, parabolic scream...) —
  đây là phần còn lại của **trait detection passive loops**, nên thuộc `trait.lua`,
  KHÔNG phải `ui.lua`, dù nằm cuối file. Chỉ phần **Heartbeat loop cho ESP/HuntAlert**
  (nếu có riêng, thường khai báo `RunService.Heartbeat:Connect`) mới thuộc `ui.lua`.
  → Người tách `trait.lua` và `ui.lua` cần đọc kỹ đoạn 4079-4513 để chia đúng:
  - Nếu loop đọc/ghi `Trait.TS.*` → `trait.lua`
  - Nếu loop update ESP highlight / hunt banner UI → `ui.lua`

---

## CROSS-MODULE STATE (đặt ở đâu, export thế nào)

| Biến/Bảng | Khai báo gốc (dòng) | Đặt ở module | Ai dùng |
|---|---|---|---|
| `C` (màu) | 11-32 | core.lua | tất cả |
| `Config` | 56-60 | core.lua | tất cả |
| `KEYBINDS` | 61-65 | core.lua | ui.lua |
| `GHOST_DB` | 51 | ghost.lua | farm, ui |
| `detectedEvidence`, `evidenceRefs`, `evidenceMissCount`, `evidenceConfirmedAbsent` | 56-72 | ghost.lua | farm, ui |
| `MISS_SKIP` | 72-ish | ghost.lua (const) | farm |
| `ghostCells`, `ghostCountLbl`, `ghostRoomLbl` | 58-59 | tạo trong ui.lua, truyền vào `Ghost.init()` sau khi UI build | ghost.lua cần ref để update |
| `farmBtn`, `farmStatusLbl` | 59 | tạo trong ui.lua, truyền vào `Farm.init()` | farm.lua |
| `detectionConns`, `conn()`, `clearDetectionConns()` | 70-71, 893-897 | ghost.lua | farm, movement (passive watchers) |
| `AUTO_FARM` | 64 | farm.lua | ui.lua (đọc `.running`) |
| `sboxToken` | 65 | farm.lua, export | ui.lua (reset khi stop) |
| `vanDoorOpened` | trong movement (dòng ~242+) | movement.lua, export bool + setter | farm.lua (reset khi map mới) |
| `playerNamesCache`, `refreshPlayerNames()` | 180-192 | ghost.lua | farm.lua |
| `Trait.TS` | 3755+ | trait.lua | ui.lua (trait card hiển thị) |
| `espCache` | trong 2392+ | esp.lua | ui.lua heartbeat loop |
| `traitLog`, `traitCard`, `traitListFrame`, `traitEmptyLbl` | 3758-3763 | UI tạo các Instance, nhưng `addTraitLog`/`setTraitVisible` ở trait.lua cần ref → truyền qua `Trait.init({ui_refs...})` | trait.lua, ui.lua |

---

## THỨ TỰ LÀM (BẮT BUỘC)

```
1. core.lua       — không phụ thuộc module nào
2. ghost.lua       — phụ thuộc core (RS, lp, getMap, getZones)
3. inventory.lua   — phụ thuộc core (getChar, getBP, getRemote)
4. movement.lua    — phụ thuộc core, ghost (findGhost cho goToGhostRoom)
5. esp.lua         — phụ thuộc core, ghost (findGhost), Config
6. farm.lua        — phụ thuộc core, ghost, inventory, movement, esp(?)
7. quests.lua      — phụ thuộc core, inventory, movement, farm helpers
8. trait.lua       — phụ thuộc core, ghost (findGhost, isHunting, getPossibleGhosts)
9. ui.lua          — phụ thuộc TẤT CẢ module trên
10. main.lua       — load theo đúng thứ tự 1-9
```

---

## SAU KHI TẤT CẢ XONG — CHECKLIST CUỐI

- [ ] Mỗi module compile được riêng lẻ (không lỗi cú pháp khi `loadstring`)
- [ ] Không còn biến nào reference mà chưa truyền qua `deps`/`init()`
- [ ] `sboxToken`, `vanDoorOpened`, `AUTO_FARM.running` đồng bộ đúng giữa farm/ui/movement
- [ ] `ghostCells`/`evidenceRefs`/`farmStatusLbl` được truyền vào ghost.lua & farm.lua
  SAU khi ui.lua đã tạo xong các Instance (đúng thứ tự gọi `init` trong main.lua)
- [ ] `Trait.TS` không bị 2 module cùng ghi đè (race condition giữa trait.lua loops
  và ui.lua trait card)
- [ ] Tổng số dòng tất cả module ≈ 4514 (cho phép lệch do comment header mỗi file)
- [ ] List ra circular dependency nếu phát hiện (ví dụ farm cần ui.farmStatusLbl,
  ui cần farm.runAutoFarm — đây KHÔNG phải circular nếu farmStatusLbl truyền qua init)

---

## GHI CHÚ CHO NGƯỜI/AI TIẾP THEO

- Nếu bạn đang làm module nào, **chỉ đọc đúng line range của mình** bằng:
  ```bash
  sed -n 'START,ENDp' blairscript.txt
  ```
- Khi xong, update cột "Trạng thái" trong bảng trên thành ✅ DONE và ghi thêm
  số dòng thực tế đã dùng (có thể lệch vài dòng so với ước tính ban đầu).
- Nếu phát hiện function nào KHÔNG nằm trong bất kỳ range nào ở bảng trên,
  ghi vào mục **MISSING DEPENDENCY** dưới đây kèm số dòng + tên hàm.

---

## MISSING DEPENDENCY (điền dần khi phát hiện)

- (chưa có — điền khi tách thực tế phát hiện thiếu)