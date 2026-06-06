import Foundation
import ExpoModulesTestCore

internal import SDWebImage

@testable import ExpoModulesCore
@testable import ExpoImage

// Exercises the cache-key contract that `writeToCacheAsync`/`readFromCacheAsync` rely on:
// image data stored under a key must be queryable back under the same key, and an unseeded key
// must miss. Each test uses a unique key and cleans up after itself so the shared `SDImageCache`
// doesn't leak state between cases.
class ImageCacheSeedingSpec: ExpoSpec {
  override class func spec() {
    // A 1x1 red PNG, the smallest valid image we can seed the cache with.
    let imageData = Data(
      base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    )!

    func makeCacheKey() -> String {
      return "expo-image-test-\(UUID().uuidString)"
    }

    describe("disk cache round-trip") {
      it("reads back an image stored under a custom key") {
        let cacheKey = makeCacheKey()
        let image = SDImageCodersManager.shared.decodedImage(with: imageData, options: nil)

        waitUntil(timeout: .seconds(10)) { done in
          // Mirrors `writeToCacheAsync`: store image + original data to disk under the custom key.
          SDImageCache.shared.store(image, imageData: imageData, forKey: cacheKey, toDisk: true) {
            // Mirrors `readFromCacheAsync`: query the cache back by the same key.
            SDImageCache.shared.queryCacheOperation(forKey: cacheKey) { cached, _, _ in
              expect(cached).notTo(beNil())
              SDImageCache.shared.removeImage(forKey: cacheKey, fromDisk: true, withCompletion: nil)
              done()
            }
          }
        }
      }

      it("reads back an image seeded straight to disk after the memory cache is cleared") {
        let cacheKey = makeCacheKey()

        waitUntil(timeout: .seconds(10)) { done in
          SDImageCache.shared.storeImageData(imageData, forKey: cacheKey) {
            // Drop the in-memory copy so the query has to hit disk, like a fresh app launch would.
            SDImageCache.shared.clearMemory()
            SDImageCache.shared.queryCacheOperation(forKey: cacheKey) { cached, _, cacheType in
              expect(cached).notTo(beNil())
              expect(cacheType) == SDImageCacheType.disk
              SDImageCache.shared.removeImage(forKey: cacheKey, fromDisk: true, withCompletion: nil)
              done()
            }
          }
        }
      }

      it("returns nil for a key that was never seeded") {
        let cacheKey = makeCacheKey()

        waitUntil(timeout: .seconds(10)) { done in
          SDImageCache.shared.queryCacheOperation(forKey: cacheKey) { cached, _, _ in
            expect(cached).to(beNil())
            done()
          }
        }
      }

      it("exposes a disk path for a seeded key") {
        let cacheKey = makeCacheKey()

        waitUntil(timeout: .seconds(10)) { done in
          SDImageCache.shared.storeImageData(imageData, forKey: cacheKey) {
            SDImageCache.shared.diskImageExists(withKey: cacheKey) { exists in
              expect(exists) == true
              expect(SDImageCache.shared.cachePath(forKey: cacheKey)).notTo(beNil())
              SDImageCache.shared.removeImage(forKey: cacheKey, fromDisk: true, withCompletion: nil)
              done()
            }
          }
        }
      }
    }
  }
}
