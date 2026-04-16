# KheirWidget — Xcode Setup Checklist

All Swift source files are already written and live at `Revenge/KheirWidget/`.
The steps below connect them to a real Xcode target.

---

## 1. Create the Widget Extension target

1. In Xcode: **File → New → Target**
2. Choose **Widget Extension** (under iOS)
3. Set:
   - **Product Name**: `KheirWidget`
   - **Bundle Identifier**: `com.kheir.KheirWidget` (or match your team's prefix)
   - Uncheck **Include Configuration App Intent**
   - Uncheck **Include Live Activity**
4. Click **Finish** → when prompted "Activate scheme?", choose **Activate**

---

## 2. Replace the auto-generated stub files

Xcode creates a `KheirWidget.swift` placeholder in the new target folder.

1. Delete the auto-generated Swift file(s) Xcode placed inside the `KheirWidget` group (right-click → **Delete → Move to Trash**).
2. In the Project Navigator, right-click the **KheirWidget** group → **Add Files to "Revenge"…**
3. Navigate to `Revenge/KheirWidget/` and add both:
   - `KheirWidgetBundle.swift`
   - `DailyAyahWidget.swift`
4. In the file-add sheet, ensure **Target Membership → KheirWidget** is checked (NOT the main Revenge target).

---

## 3. Add App Groups capability — main app target

1. Select the **Revenge** project in the Navigator → choose the **Revenge** app target
2. **Signing & Capabilities** tab → click **+ Capability** → **App Groups**
3. Click **+** inside the App Groups box → add: `group.com.kheir.shared`

---

## 4. Add App Groups capability — widget target

1. Select the **KheirWidget** target
2. **Signing & Capabilities** → **+ Capability** → **App Groups**
3. Add the **exact same** identifier: `group.com.kheir.shared`

> Both targets must share the identical string or `CacheManager` will fall back to
> the Documents directory and the widget will show placeholder data.

---

## 5. Add shared source files to the widget target

The widget cannot import the Revenge app module, so shared models and services must
be compiled into the widget target directly via **Target Membership**.

Select each file listed below in the Project Navigator → open the **File Inspector**
(right panel, first tab) → under **Target Membership** check **KheirWidget**:

| File | Location |
|------|----------|
| `CacheManager.swift` | `Revenge/Core/Services/` |
| `QuranModels.swift` | `Revenge/Core/Models/` |
| `BookmarkModels.swift` | `Revenge/Core/Models/` |
| `HadithModels.swift` | `Revenge/Core/Models/` |
| `JournalModels.swift` | `Revenge/Core/Models/` |
| `Date+Extensions.swift` | `Revenge/Core/Extensions/` |
| `Constants.swift` | `Revenge/Core/Utilities/` |
| `AppSettings.swift` | `Revenge/Core/Models/` |

> `AppConstants.swift` imports `CoreLocation`, which is fine for the widget target.
> If you see linker errors, add it too.

---

## 6. Build and verify

1. Select the **KheirWidget** scheme in the toolbar
2. **Product → Build** (`Cmd+B`) — resolve any missing-symbol errors by verifying
   Target Membership in Step 5
3. Run on a Simulator or device; the widget simulator launches automatically

---

## 7. Add the widget to the Home Screen

1. On the Simulator/device Home Screen, **long-press** any empty space
2. Tap **+** (top-left) → search **Kheir** or **Daily Ayah**
3. Add the **Small** or **Medium** size widget

---

## 8. Deep-link wiring (optional — do later)

The widget fires `kheir://home/ayah` via `.widgetURL(...)`.  
Handle this in `RevengeApp.swift` via `.onOpenURL { url in … }` to scroll/highlight
the ayah on the Home screen.

---

## Troubleshooting

| Symptom | Likely cause |
|---------|-------------|
| Widget shows placeholder forever | App Group not configured on both targets, or app hasn't run once to populate the cache |
| Build error: `DailyAyah` undeclared | `QuranModels.swift` not added to KheirWidget target membership |
| Build error: `CacheManager` undeclared | `CacheManager.swift` not added to KheirWidget target membership |
| `containerURL` returns `nil` at runtime | Bundle ID mismatch — both targets must have the **same** App Group string |
