import Foundation

func memoize<Input: Hashable, Output>(_ function: @escaping (Input) -> Output) -> (Input) -> Output {
    var storage = [Input: Output]()
    let queue = DispatchQueue(label: "memoize.queue")

    return { input in
        return queue.sync {
            if let cached = storage[input] {
                return cached
            }

            let result = function(input)
            storage[input] = result
            return result
        }
    }
}
