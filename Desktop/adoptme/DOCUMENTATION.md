# AdoptHub — Adopt Me! Auto-Farm Script Documentation

## Tổng quan

**AdoptHub** là một script auto-farm cho game **Adopt Me!** trên Roblox, được viết bằng Lua. Script gồm 4 phần chính (loader + 3 modules) và một file dữ liệu Excel + log network.

---

## Cấu trúc file

| File | Vai trò |
|------|---------|
| `main.lua` | Loader — khởi tạo, cache remotes, load parts 1→2→3 |
| `part1.lua` | Services, remotes, helpers, quest queue/de-dup system |
| `part2.lua` | Farm logic — daily, quest handling, auto loops |
| `part3.lua` | Frosted glass UI với 3 tabs |
| `New Text Document.txt` | Network log (remote event traffic) |
| `AdoptMe_Full_Data_2026.xlsx` | File Excel dữ liệu |

---

## 1. main.lua — Loader

**Mục đích:** Entry point, load và chain các parts lại với nhau.

- Set global `_G.AdoptHub = true/false` (dùng để kill tất cả loops)
- **Pre-cache remotes** từ `ReplicatedStorage` vào `_G.CachedRemotes`
- Xóa GUI cũ nếu có (`AdoptHubUI`)
- Hỗ trợ 2 nguồn load:
  - **Local:** `C:/Users/Admin/Desktop/adoptme/` (dùng `readfile`)
  - **Remote:** GitHub raw (`nguyenhung7a3cmt/adopt-me-script`)
- `buildRemoteCache()` — chạy 3 lần (ngay lập tức, 0.5s, 2s) để đảm bảo cache đầy đủ
- `loadPart(file, arg)` — đọc source → `loadstring` → pcall với arg truyền vào
- Chain: `part1.lua` → trả về state `S` → truyền vào `part2.lua` → truyền tiếp vào `part3.lua`

---

## 2. part1.lua — Core & State

**Mục đích:** Định nghĩa tất cả services, remote references, helpers, và quest queue system.

### Services
- `Players`, `ReplicatedStorage`, `RunService`, `TweenService`, `UserInputService`

### Config (toggle states)
| Key | Mặc định | Chức năng |
|-----|----------|-----------|
| `AutoDaily` | false | Auto daily tasks |
| `AutoFarm` | false | Auto pet care farming |
| `AutoPizza` | false | Auto pizza job |
| `AutoCollect` | false | Auto collect bucks |

### Remote Cache System
- `API` = `RS:FindFirstChild("API")`
- `NET` = `RS:FindFirstChild("adoptme_new_net")`
- `getRemote(parent, path)` — traverse path theo `/`
- `getRemoteWait(parent, path, timeout)` — tương tự nhưng có WaitForChild
- `getRemoteByName(name)` — tìm trong `_G.CachedRemotes` (prefix match + suffix match), fallback scan live
- `tryFindNetRemote(path)` — resolve path dạng `adoptme_new.modules.Dailies.DailiesNetService:9` (chấm + index)
- `findDailiesRemote(index)` — tìm folder `DailiesNetService` trong NET, sort children by name, lấy phần tử thứ `index`

### Remotes được map
- **Data:** `DataChanged`, `DataInit`, `DataPartial`
- **Daily:** `ClaimDailyReward`, `ClaimStarReward`, `DailiesEvent1` (index 9), `DailiesEvent2` (index 15)
- **Pet/Ailment:** `ProgressPetMeAilment`, `ProgressDirtyAilment`, `ChooseMysteryAilment`, `PetAilmentCompleted`, `BabyAilmentCompleted`, `ShowHealingEffect`, `PetProgressed`, `PetHatched`, `FocusPet`, `UnfocusPet`, `ReplicateReactions`, `ResetPetNetwork`, `ClaimPetProgression`
- **Pizza:** `PizzaClaim` (PizzaShopClaimDough), `PizzaNav` (NavigateToPizzaShopConveyor)
- **Minigame:** `MinigameJoin` (AttemptJoin), `MicrogameStart` (AttemptStart)
- **Khác:** `TeleToLocation`, `PayCollect` (Collect)

### Ailment Map
```
hungry, thirsty, sleepy, bored, sick, walk, toilet → ProgressPetMeAilment
dirty → ProgressDirtyAilment
mystery → ChooseMysteryAilment
```

### Helpers
| Function | Chức năng |
|----------|-----------|
| `safewait(t)` | Wait tuần hoàn, kiểm tra `_G.AdoptHub` |
| `jitter(base)` | base + random(-0.5, 0.5) |
| `tryCall(remote, ...)` | FireServer / InvokeServer có pcall |
| `retryCall(remote, maxTry, ...)` | Retry call tối đa maxTry lần |

### Quest Queue System
- `activeTasks{}`, `activeTaskMap{}`, `completedTaskCache{}`
- `normalizeTaskData(taskData)` — chuẩn hóa task data từ nhiều format khác nhau
- `classifyQuest(task)` — phân loại quest dựa trên keywords: `pizza`, `minigame`, `teleport`, `collect`, `pet`
- `getTaskKey(task)` — tạo key unique cho task (id|name|rawType|kind)
- `pushTask(taskData)` — thêm task vào queue (chống trùng qua `activeTaskMap`)
- `popTask()` — lấy task từ đầu queue
- `markTaskDone(task)` — đánh dấu hoàn thành + cache thời gian
- `dedupeTask(task, window)` — kiểm tra task đã làm trong window (giây)

### Debug State
- `debugState.step`, `.detail`, `.lastError`, `.updatedAt`
- `setDebugStep(step, detail)`, `setDebugError(err)`, `getDebugState()`

---

## 3. part2.lua — Farm Logic

**Mục đích:** Xử lý tự động hóa các quest, daily tasks, collect bucks, pizza job.

### Daily Login
- `claimDailyLogin()` — Claim daily reward + star reward (retry 3 lần)

### Pet Care
- `PET_AILMENTS = {"hungry", "sleepy", "dirty", "sick", "thirsty", "bored", "walk", "toilet"}`
- `findActivePet()` — tìm pet trong `Workspace.Pets` theo Owner value/attribute
- `sendPetReaction(pet, reactionName)` — gửi reaction qua `ReplicateReactions`
- `focusActivePet()` — focus pet qua `FocusPet` remote
- `clickAilmentButtons()` — click UI buttons:
  - **Cách 1:** `FocusPetApp.AilmentContainer.End`
  - **Cách 2:** `AilmentsMonitorApp.MobileAilmentContainer.Ailment`
- `progressPetCare(taskInfo)` — click ailment buttons nhiều lần

### Quest Handlers
| Handler | Chức năng |
|---------|-----------|
| `runPizzaQuest()` | PizzaNav → PizzaClaim ×6 |
| `runMinigameQuest()` | MinigameJoin → MicrogameStart |
| `runCollectQuest()` | PayCollect |
| `runTeleportQuest(task)` | TeleToLocation (có/location) |
| `progressPetCare(task)` | Click ailment UI buttons |

### Remote Event Hooks (Dailies)
- Hook `DailiesEvent1`, `DailiesEvent2`, `DataInit`, `DataChanged`, `DataPartial`
- `inspectDailyPayload(...)` — parse args để tìm task data (từ keys: tasks, quests, entries, active, daily_quests)
- `inspectDataContainer(container)` — scan container tìm daily/quest keys
- Hook `PetAilmentCompleted`, `PetProgressed` → `rememberQuestSignal()`

### Fallback Quests
- `pumpFallbackQuests()` — tạo task fallback dựa trên recent signals (pet, ailment, level_up)

### Loops (chạy trong task.spawn)
| Loop | Interval | Chức năng |
|------|----------|-----------|
| `runDailyLoop()` | liên tục | Pop task từ queue → handle → fallback auto farm |
| `runCollectLoop()` | ~30s | Auto collect bucks |
| `runPizzaLoop()` | ~chục giây | PizzaNav + PizzaClaim ×8 |
| `runPetCareLoop()` | 5s | Fallback (thực tế daily loop xử lý) |

### Flow xử lý task
1. Remote event → `inspectDailyPayload` → `pushTask`
2. `runDailyLoop` → `popTask` → `handleTask`
3. `handleTask` → `classifyQuest` → chọn handler → execute
4. Nếu AutoFarm và không có task → fallback pet care loop

---

## 4. part3.lua — Frosted Glass UI

**Mục đích:** Giao diện người dùng trong game.

### Style
- Dark theme (nền `#0E0E12`, card `#181820`)
- Frosted glass với blur effect + border mờ
- Font Code (monospace)

### Components
- **Window:** 300×420, center màn hình, có shadow, drag được
- **Title Bar:** AdoptHub v1.0 + minimize (−) + close (×)
- **Status Bar:** Hiển thị trạng thái realtime (● idle, ● farming...)
- **Tabs:** Farm | Daily | Settings (chuyển tab có tween)

### Tab 1: Farm
| Control | Chức năng |
|---------|-----------|
| Auto Pet Care toggle | Bật/tắt `Config.AutoFarm` |
| Auto Pizza Job toggle | Bật/tắt `Config.AutoPizza` |
| Auto Collect Bucks toggle | Bật/tắt `Config.AutoCollect` |
| Stop All Farms button | Gọi `stopAll()` |
| Debug box | Hiển thị step/detail/error realtime (update mỗi 0.25s) |

### Tab 2: Daily
| Control | Chức năng |
|---------|-----------|
| Auto Daily Tasks toggle | Bật/tắt `Config.AutoDaily` |
| Claim Daily Login Now button | Chạy `claimDailyLogin()` |
| Run Daily Tasks Now button | Bật AutoDaily trong 0.5s |
| Info box | "Tasks auto-detected via DailiesNetService hook" |

### Tab 3: Settings
| Control | Chức năng |
|---------|-----------|
| Destroy GUI button | Tắt `_G.AdoptHub`, xóa GUI + blur |
| Version info | AdoptHub v1.0 |

### Interactions
- **Drag:** Title bar → InputBegan/InputChanged/InputEnded
- **Minimize:** Tween chiều cao xuống 44px (chỉ còn title bar)
- **Close:** Tween scale về 0 → destroy
- **Open animation:** Pop-in từ center

---

## 5. New Text Document.txt — Network Log

File log chứa traffic remote event giữa Client (C→S) và Server (S→C) trong game Adopt Me!:

### Các remote event phổ biến
- `PetAPI/ReplicateModifiersToClient` — Pet modifiers (eyes, forms, effects, animations)
- `PetAPI/ClearModifiers` — Xóa modifiers
- `AilmentsAPI/PetAilmentCompleted` — Pet ailment hoàn thành (kèm reward: bucks, xp, alt_currency)
- `PetAPI/PetProgressed` — Pet level up
- `PerformanceLogger/*` — Game performance logging (logUserExitState, setMisc, setMemory)
- `AdoptAPI/FocusPet`, `AdoptAPI/UnfocusPet` — Focus/unfocus pet
- `JournalAPI/CommitCollection` — Commit journal collection
- `ErrorReportAPI/SendUniqueError` — Gửi lỗi

### Một số pet IDs trong log
- `endangered_2026_black_tiger`, `journey_2026_pilot_gull`, `summerfest_2024_balloon_unicorn`, `house_pets_2025_siamese_cat`, `halloween_2025_slimingo`, `endangered_2026_galapagos_sea_lion`, `endangered_2026_california_condor`

---

## 6. AdoptMe_Full_Data_2026.xlsx

File Excel nhị phân — không đọc trực tiếp được. Cần mở bằng Excel để xem nội dung.

---

## Luồng hoạt động tổng thể

```
main.lua
  ├── Pre-cache remotes vào _G.CachedRemotes
  ├── load part1.lua → state S (services, remotes, helpers, quest queue)
  ├── load part2.lua với S → Farm logic (hooks, loops, handlers)
  └── load part3.lua với S → Frosted Glass UI
```

### Khi bật Auto Farm:
1. Part2 hook remote events từ game
2. Khi có daily/quest data → parse → push vào queue
3. Daily loop pop task → classify → handler tương ứng
4. Nếu không có task → fallback pet care
5. UI debug box hiển thị trạng thái realtime

### Kill switch:
- `_G.AdoptHub = false` → tất cả loops dừng
- Close/Destroy GUI button hoặc set global
