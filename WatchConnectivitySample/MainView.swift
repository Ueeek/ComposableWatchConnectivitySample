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
        case watchConnectivity(WatchConnectivityClient.Action)
    }
    
    @Dependency(\.watchConnectivityClient) var watchClient
    
    var body: some Reducer<State, Action> {
        CombineReducers {
            watchClientReducer
            Reduce { state, action in
                switch action {
                    case .appearTask:
                        return .run { send in
                            await watchClient.activate()
                            await withTaskGroup(of: Void.self) { group in
                                group.addTask {
                                    // WCSessionDelegateのmethodを購読し、actionとしてsendする。
                                    await withTaskCancellation(id: CancelID.watchConnectivity, cancelInFlight: true) {
                                        for await action in await watchClient.delegate() {
                                            await send(.watchConnectivity(action), animation: .default)
                                        }
                                    }
                                }
                            }
                        }
                    case .sendCurrentDate:
                        // WatchClientを使用して、dataを送る。
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
                    // WatchとのSessionのStatus. `watchClient.activate()`の結果。
                case .watchConnectivity(.activationDidCompleteWith(let status)):
                    let activatedStatus = status == .activated ? "activated" :"not activated"
                    state.message = "session " + activatedStatus
                    return .none
                    // `watchClient.sendMessage((key:val))`が失敗した時に呼ばれる。
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
        .task { await store.send(.appearTask).finish() }
    }
}
