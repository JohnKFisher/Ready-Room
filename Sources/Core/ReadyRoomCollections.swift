import Foundation

public enum ReadyRoomCollections {
    public static func dictionaryLastValueWins<K: Hashable, V, S: Sequence>(
        from pairs: S
    ) -> [K: V] where S.Element == (K, V) {
        var dictionary: [K: V] = [:]
        for (key, value) in pairs {
            dictionary[key] = value
        }
        return dictionary
    }
}

