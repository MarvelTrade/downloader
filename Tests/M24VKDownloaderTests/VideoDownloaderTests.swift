import Testing
@testable import M24VKDownloader

@Test func supportedVideoSources() {
    #expect(URLValidator.isSupportedVideoURL("https://www.youtube.com/watch?v=abc"))
    #expect(URLValidator.isSupportedVideoURL("https://vk.com/video-1_2"))
    #expect(URLValidator.isSupportedVideoURL("https://www.m24.ru/videos/test"))
}

@Test func bookAndUnknownSourcesAreRejected() {
    #expect(URLValidator.source(from: "https://flibusta.su/book/123") == nil)
    #expect(URLValidator.source(from: "https://example.com/file.pdf") == nil)
}

@Test func filenameSanitizerKeepsVideoNameSafe() {
    #expect(FilenameSanitizer.sanitize("Новости: день/вечер") == "Новости- день-вечер")
}
