import XCTest
@testable import HomeAI

final class WebSearchServiceTests: XCTestCase {
    var webSearchService: WebSearchService!
    
    override func setUp() {
        super.setUp()
        webSearchService = WebSearchService()
    }
    
    override func tearDown() {
        webSearchService = nil
        super.tearDown()
    }
    
    func testLocationExtractionForValrico() {
        let q1 = "What is the current weather in Valrico, FL 33596?"
        let loc1 = webSearchService.extractLocation(from: q1)
        XCTAssertTrue(loc1.contains("Valrico") || loc1.contains("33596"), "Expected location to contain Valrico or 33596, got: \(loc1)")
        
        let q2 = "current weather for valricio, fl 33596"
        let loc2 = webSearchService.extractLocation(from: q2)
        XCTAssertTrue(loc2.contains("Valrico") || loc2.contains("33596"), "Expected location to fix typo and contain Valrico/33596, got: \(loc2)")
        
        let q3 = "weather in 33596"
        let loc3 = webSearchService.extractLocation(from: q3)
        XCTAssertEqual(loc3, "33596")
    }
    
    func testWeatherQueryIntentDetection() {
        XCTAssertTrue(webSearchService.isWeatherQuery("What's the weather today?"))
        XCTAssertTrue(webSearchService.isWeatherQuery("valricio, fl 33596 temperature"))
        XCTAssertTrue(webSearchService.isWeatherQuery("forecast for tomorrow"))
        XCTAssertFalse(webSearchService.isWeatherQuery("Write a Swift function to sort an array"))
    }
    
    func testGeneralQueryIntentDetection() {
        XCTAssertTrue(webSearchService.shouldPerformSearch(for: "current weather for valricio, fl 33596"))
        XCTAssertTrue(webSearchService.shouldPerformSearch(for: "What is the latest news today?"))
        XCTAssertTrue(webSearchService.shouldPerformSearch(for: "weather 33596"))
        XCTAssertFalse(webSearchService.shouldPerformSearch(for: "explain quantum physics basics"))
    }
    
    func testKnowledgeRefusalDetection() {
        let refusal1 = "I am sorry, but I do not have access to real-time information or live weather data."
        XCTAssertTrue(webSearchService.isRefusalDueToLackOfKnowledge(refusal1))
        
        let refusal2 = "As an AI, I don't have access to live meteorological data."
        XCTAssertTrue(webSearchService.isRefusalDueToLackOfKnowledge(refusal2))
        
        let validAnswer = "The current temperature in Valrico, FL 33596 is 77°F with 92% humidity."
        XCTAssertFalse(webSearchService.isRefusalDueToLackOfKnowledge(validAnswer))
    }
    
    func testLiveWeatherFetchForValricoFL33596() async {
        let result = await webSearchService.fetchWeather(for: "current weather for valricio, fl 33596")
        XCTAssertNotNil(result, "Weather fetch for Valrico FL 33596 should return a valid result")
        if let res = result {
            XCTAssertTrue(res.isWeather)
            XCTAssertFalse(res.formattedContext.isEmpty)
        }
    }
    
    func testConversationalQueryIntentExclusion() {
        let conversationalQueries = [
            "This is way better Thank You",
            "Thank you",
            "thanks",
            "appreciate it",
            "hello",
            "tell me a story about a taco princess",
            "write a swift function to parse json",
            "ok",
            "yes"
        ]
        
        for q in conversationalQueries {
            XCTAssertTrue(webSearchService.isConversationalQuery(q), "Query '\(q)' should be detected as conversational")
            XCTAssertFalse(webSearchService.shouldPerformSearch(for: q), "Query '\(q)' should NOT perform search")
        }
    }
}
