import ComposableArchitecture
import ComposableWatchConnectivity
import SwiftUI

enum CancelID {
    case watchConnectivity
}

@Reducer
struct MainReducer {
    @ObservableState
    struct State: Equatable {
        var message: String = ""
    }
    
    enum Action:  Sendable {
        case appearTask
        case sendCurrentDate
        
        // To receive the actions that emit from WCSessionDelegate via WatchConnectivityClient
        case watchConnectivity(WatchConnectivityClient.Action)
    }
    
    // WatchConnectivityClient is defined as DependencyClient in the library.
    @Dependency(\.watchConnectivityClient) var watchClient
    
    var body: some Reducer<State, Action> {
        CombineReducers {
            // Separate Reducer for easier understanding
            watchClientReducer
            Reduce { state, action in
                switch action {
                    case .appearTask:
                        return .run { send in
                            // Activate the session
                            await watchClient.activate()
                            
                            // Start subscribing
                            await withTaskGroup(of: Void.self) { group in
                                group.addTask {
                                    await withTaskCancellation(id: CancelID.watchConnectivity, cancelInFlight: true) {
                                        for await action in await watchClient.delegate() {
                                            await send(.watchConnectivity(action), animation: .default)
                                        }
                                    }
                                }
                            }
                        }
                    case .sendCurrentDate:
                        // Send data via WatchClient
                        state.message = "send Data'"
                        return .run { _ in
                            if let data = try? JSONEncoder().encode(Date.now) {
                                await watchClient.sendMessage(("date", data))
                            }
                        }
                    case .watchConnectivity:
                        return .none
                }
            }
        }
    }
    
    // WatchClientのactionは分かりやすいように切り分ける
    @ReducerBuilder<State, Action>
    var watchClientReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                    // Result of establishing a session
                case .watchConnectivity(.activationDidCompleteWith(let status)):
                    let activatedStatus = status == .activated ? "activated" :"not activated"
                    state.message = "session " + activatedStatus
                    return .none
                case .watchConnectivity(.sendFail(let error)):
                    state.message = "sendFail with \(error.localizedDescription)"
                    return .none
                default:
                    return .none
            }
        }
    }
}

struct MainView: View {
    var store: StoreOf<MainReducer>
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("Log:")
                Text("\(store.message)")
            }
            Button(
                action: {
                    store.send(.sendCurrentDate)
                }, label: {
                    Text("Send CurrentDate to Watch")
                    
                }
            )
        }
        // When view is appeared, setup the WatchConnectivityClient
        .task { await store.send(.appearTask).finish() }
    }
}
