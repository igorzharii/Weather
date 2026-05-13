# Weather – ForeFlight iOS Assignment

## Time Spent

~6 hours total.

## Architecture

**MVVM + Coordinators**, UIKit + SwiftUI interoperation, Combine — no third-party dependencies.

```
AppDelegate
  └─ AppCoordinator
       └─ AirportListCoordinator
            ├─ AirportListViewController    ←→  AirportListViewModel          (UIKit)
            ├─ WeatherDetailViewController  ←→  WeatherDetailViewModel         (UIKit + SwiftUI)
            └─ UIHostingController              SettingsView ←→ SettingsViewModel  (SwiftUI)
```

### Layer responsibilities

| Layer | Files | Role |
|---|---|---|
| Coordinators | `AppCoordinator`, `AirportListCoordinator` | Own all `push`/`setViewControllers` calls; ViewControllers never import each other |
| ViewModels | `AirportListViewModel`, `WeatherDetailViewModel`, `SettingsViewModel` | All state, business logic, display-data formatting; publish via Combine `@Published` |
| ViewControllers | `AirportListViewController`, `WeatherDetailViewController` | Bind to VM outputs with `sink`; forward user actions back to VM; zero navigation or business logic |
| SwiftUI Views | `SettingsView`, `WeatherContentView` | Declarative leaf UI; driven by the same ViewModels |
| Display types | `WeatherDisplayContent`, `WeatherSection`, `WeatherRow` | UIKit/SwiftUI-agnostic value types the VM builds; rendered by whichever framework hosts them |
| Networking | `WeatherService` (`WeatherServiceProtocol`) | async/await; sets `ff-coding-exercise: 1` header |
| Storage | `AirportStore` (`@MainActor`) | UserDefaults airport list; file-cached JSON per airport |
| Settings | `AutoRefreshSettings`, `RefreshInterval` | UserDefaults-backed refresh interval |

### UIKit + SwiftUI interoperability

Two patterns are demonstrated:

**1 — SwiftUI view pushed onto a UIKit navigation stack (`SettingsView`)**
`AirportListCoordinator` wraps `SettingsView` in a `UIHostingController` and pushes it with the standard `navigationController.pushViewController(_:animated:)`. The UIKit nav bar, back button, and large-title behaviour all work automatically. `SettingsViewModel` conforms to `ObservableObject` so SwiftUI can observe it directly.

**2 — SwiftUI view embedded inside a UIKit view controller (`WeatherContentView`)**
`WeatherDetailViewController` adds a `UIHostingController<WeatherContentView>` as a child view controller, pinning its view below the UIKit `UISegmentedControl`. When `displayContent` changes, the VC updates `contentHost.rootView` with fresh data — SwiftUI diffs and redraws only what changed. The segment control and loading/error overlays remain UIKit, showing both frameworks side-by-side in the same screen.

### Other key design decisions

- **Coordinators hold navigation** — VCs expose callbacks (`onShowDetail`, `onShowSettings`) which coordinators wire up; VCs are reusable and independently testable.
- **ViewModels are `@MainActor`** — mutable state is always on the main thread; `Task {}` inside VMs inherits the actor context, `await service.fetchWeather()` suspends off-actor for the network hop, then resumes on main.
- **`WeatherDisplayContent` is the single rendering input** — both the UIKit VC and the SwiftUI view receive the same value type; no imperative `show/hide` calls scattered around lifecycle methods.
- **Cache-then-fetch** — the detail VM loads cached JSON instantly on `init`; the live fetch updates the same `@Published` property.
- **Auto-refresh** — a `Timer` in `AirportListViewModel` fires at the chosen interval and re-fetches all airports, caching results and triggering a list reload via `@Published var airports`.

## Test Suite

`WeatherTests` is a host-app unit-test bundle. All tests are offline (no real network).

| File | Coverage |
|---|---|
| `WeatherModelsTests` | JSON decode/encode round-trips, optional fields, malformed input |
| `WeatherServiceTests` | Header injection, identifier uppercasing, HTTP errors, network errors, malformed JSON — via `MockURLProtocol` |
| `AirportStoreTests` | Add/dedup/remove, case-insensitivity, UserDefaults persistence, cache write/read/overwrite |
| `AirportListViewModelTests` | Add/remove/dedup, whitespace trimming, uppercasing, out-of-bounds safety, navigation callbacks, subtitle formatting |
| `WeatherDetailViewModelTests` | Fetch success/failure, cache-first behaviour, mode switching (conditions ↔ forecast), section structure, row values, cancellation safety |
| `Mocks/MockURLProtocol` | `URLProtocol` subclass for `WeatherServiceTests` |
| `Mocks/MockWeatherService` | `WeatherServiceProtocol` conformance returning a pre-configured `Result` for ViewModel tests |

## References

- Apple Developer Documentation (URLSession, UIKit, Combine, ISO8601DateFormatter)
- ForeFlight API endpoint as specified in the assignment

## Third-Party Libraries

None.

## Known Issues / Limitations

- No pull-to-refresh on the detail view (nav-bar Refresh button is the intended affordance).
- Forecast period dates from some airports may use timezone offset formats not covered by the two-pass ISO8601 formatter; they fall back to displaying the raw string.
