//
//  MainView.swift
//  WatchConnectivitySample Watch App
//
//  Created by KoichiroUeki on 2024/12/15.
//

import ComposableArchitecture
import ComposableWatchConnectivity
import Foundation
import SwiftUI

enum CancelID {
    case watchConnectivity
}

@Reducer
struct MainReducer {
    @ObservableState
    struct State: Equatable {
        var receivedData: String = ""
    }
    
    enum Action:  Sendable {
        case appearTask
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
                                    await withTaskCancellation(id: CancelID.watchConnectivity, cancelInFlight: true) {
                                        for await action in await watchClient.delegate() {
                                            await send(.watchConnectivity(action), animation: .default)
                                        }
                                    }
                                }
                            }
                        }
                    case .watchConnectivity:
                        return .none
                }
            }
        }
    }
    
    @ReducerBuilder<State, Action>
    var watchClientReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                case .watchConnectivity(.didReceiveMessage(let message)):
                    // WatchClientを使用して、dataを受け取る
                    if let data = message?["date"] as? Data,
                       let receivedDate = try? JSONDecoder().decode(Date.self, from: data) {
                        state.receivedData = receivedDate.description
                    } else {
                        state.receivedData = "fail to parse"
                    }
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
                Text("Received Date:")
                Text("\(store.receivedData)")
            }
        }
        .task { await store.send(.appearTask).finish() }
    }
}
