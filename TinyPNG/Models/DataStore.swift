//
//  DataStore.swift
//  TinyPNG
//
//  Created by Logan Wang on 2023/6/15.
//

import Foundation

final class DataStore: ObservableObject {
    @Published var pngs: [TinyImage] = []
}
