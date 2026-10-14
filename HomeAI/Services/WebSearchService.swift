import Foundation

public struct WebSearchResult: Sendable {
    public let query: String
    public let formattedContext: String
    public let summaryTitle: String
    public let sourceURLs: [String]
    public let isWeather: Bool
}

public final class WebSearchService: @unchecked Sendable {
    public static let shared = WebSearchService()
    
    private static let contextDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()
    
    private let urlSession: URLSession
    
    public init(session: URLSession = .shared) {
        self.urlSession = session
    }
    
    // MARK: - Query Intent Detection
    
    public func isExplicitSearchCommand(_ query: String) -> Bool {
        let lower = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let explicitPrefixes = [
            "search the web for", "search online for", "search the internet for",
            "browse the web for", "look up online", "google ", "duckduckgo ",
            "search for ", "find on the web", "search duckduckgo for"
        ]
        return explicitPrefixes.contains(where: { lower.hasPrefix($0) || lower.contains($0) })
    }
    
    public func isConversationalQuery(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return true }
        
        let conversationalPhrases = [
            "thank you", "thanks", "thx", "appreciate it", "great", "cool", "nice",
            "awesome", "perfect", "good job", "you're welcome", "your welcome",
            "hello", "hi", "hey", "good morning", "good evening", "good afternoon",
            "bye", "goodbye", "see ya", "ok", "okay", "sure", "got it", "understood",
            "yes", "no", "yep", "nope", "tell me a story", "write a story",
            "write code", "help me code", "write a poem", "tell me a joke",
            "write a swift", "write a function", "write a swift function"
        ]
        
        for phrase in conversationalPhrases {
            if trimmed == phrase || trimmed.hasPrefix(phrase) || trimmed.hasSuffix(phrase) || trimmed.contains(phrase) {
                // If it doesn't explicitly contain weather or news keywords, it's conversational
                if !isWeatherQuery(trimmed) && !trimmed.contains("news") && !trimmed.contains("stock price") && !isExplicitSearchCommand(trimmed) {
                    return true
                }
            }
        }
        return false
    }
    
    public func isInformationSeekingQuery(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return false }
        if isConversationalQuery(trimmed) { return false }
        
        let nonInfoPrefixes = [
            "i want to", "i would like to", "i want", "i wish", "i need to",
            "can you pretend", "roleplay", "imagine that", "act as",
            "write a", "compose a", "tell me a"
        ]
        if nonInfoPrefixes.contains(where: { trimmed.hasPrefix($0) }) {
            return false
        }
        
        return true
    }
    
    public func shouldPerformSearch(for query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return false }
        
        // Exclude purely conversational / gratitude / greeting / generic coding messages
        if isConversationalQuery(trimmed) {
            return false
        }
        
        // Explicit search commands
        if isExplicitSearchCommand(trimmed) {
            return true
        }
        
        // Weather indicators
        if isWeatherQuery(trimmed) {
            return true
        }
        
        // Specific live / real-time query patterns
        let liveIndicators = [
            "\\b(latest|breaking)\\s+news\\b",
            "\\b(current|today's)\\s+stock\\s+price\\b",
            "\\bstock\\s+price\\s+of\\b",
            "\\bwho\\s+won\\s+the\\b",
            "\\blive\\s+(sports?\\s+)?score\\b",
            "\\bcurrent\\s+traffic\\s+in\\b",
            "\\bstatus\\s+of\\s+flight\\b",
            "\\brelease\\s+date\\s+of\\b",
            "\\bwho\\s+is\\s+the\\s+current\\s+president\\b",
            "\\bwho\\s+is\\s+the\\s+current\\s+prime\\s+minister\\b"
        ]
        
        for pattern in liveIndicators {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                return true
            }
        }
        
        // Check for 5-digit US zip codes with location/weather context
        let zipRegex = try? NSRegularExpression(pattern: "\\b\\d{5}\\b")
        if let matches = zipRegex?.numberOfMatches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)), matches > 0 {
            if isWeatherQuery(trimmed) || trimmed.contains("weather") || trimmed.contains("forecast") || trimmed.contains("temperature") {
                return true
            }
        }
        
        return false
    }
    
    public func isWeatherQuery(_ query: String) -> Bool {
        let lower = query.lowercased()
        let weatherKeywords = [
            "weather", "forecast", "temperature", "rain", "sunny", "humidity",
            "degrees", "wind speed", "precipitation", "radar", "climate", "storm",
            "snow", "hot outside", "cold outside"
        ]
        
        for kw in weatherKeywords {
            if lower.contains(kw) {
                return true
            }
        }
        
        return false
    }
    
    public func isRefusalDueToLackOfKnowledge(_ response: String) -> Bool {
        let lower = response.lowercased()
        let refusalPhrases = [
            "don't have access to real-time",
            "do not have access to real-time",
            "don't have access to live",
            "do not have access to live",
            "cannot check current",
            "can't check current",
            "unable to browse the internet",
            "cannot provide real-time",
            "as an ai, i don't have access to real-time",
            "as an ai, i do not have access to real-time",
            "as an ai, i don't have access to the internet",
            "as an ai, i do not have access to the internet",
            "as an ai, i don't have access to live",
            "as an ai, i do not have access to live",
            "as an ai, i don't have access to current",
            "as an ai, i do not have access to current",
            "my knowledge cutoff",
            "i don't have live weather",
            "i do not have live weather",
            "i cannot provide live weather",
            "i am unable to provide real-time"
        ]
        
        for phrase in refusalPhrases {
            if lower.contains(phrase) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Primary Retrieval Dispatcher
    
    public func searchOrRetrieve(query: String) async -> WebSearchResult? {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return nil }
        
        AppLogger.network.info("Executing web search for query: \(cleanQuery, privacy: .private)")
        
        if isWeatherQuery(cleanQuery) || containsLocationOrZip(cleanQuery) {
            if let weatherResult = await fetchWeather(for: cleanQuery) {
                return weatherResult
            }
        }
        
        // Fallback or general query -> DuckDuckGo search
        if let searchResult = await performWebSearch(query: cleanQuery) {
            return searchResult
        }
        
        // Final fallback: try weather if it looked like a location
        return await fetchWeather(for: cleanQuery)
    }
    
    private func containsLocationOrZip(_ query: String) -> Bool {
        let zipRegex = try? NSRegularExpression(pattern: "\\b\\d{5}\\b")
        if let matches = zipRegex?.numberOfMatches(in: query, range: NSRange(query.startIndex..., in: query)), matches > 0 {
            return true
        }
        return false
    }
    
    // MARK: - Weather Retrieval
    
    public func fetchWeather(for query: String) async -> WebSearchResult? {
        let location = extractLocation(from: query)
        guard !location.isEmpty else { return nil }
        
        AppLogger.network.debug("Resolved weather location query: '\(location)'")
        
        // 1. Try wttr.in JSON format
        if let jsonResult = await fetchWttrInJson(location: location, originalQuery: query) {
            return jsonResult
        }
        
        // 2. Try wttr.in custom text format
        if let textResult = await fetchWttrInText(location: location, originalQuery: query) {
            return textResult
        }
        
        // 3. Try Open-Meteo fallback
        if let openMeteoResult = await fetchOpenMeteoWeather(location: location, originalQuery: query) {
            return openMeteoResult
        }
        
        return nil
    }
    
    public func extractLocation(from query: String) -> String {
        var clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Normalize common typo "valricio" -> "Valrico"
        clean = clean.replacingOccurrences(of: "valricio", with: "Valrico", options: .caseInsensitive)
        
        let prefixesToRemove = [
            "what is the current weather in",
            "what is current weather in",
            "what's the current weather in",
            "what's current weather in",
            "what is the weather in",
            "what's the weather in",
            "what is the weather for",
            "what's the weather for",
            "current weather for",
            "current weather in",
            "weather forecast for",
            "weather forecast in",
            "how is the weather in",
            "how's the weather in",
            "weather in",
            "weather for",
            "temperature in",
            "temperature for",
            "forecast for",
            "forecast in",
            "weather"
        ]
        
        let lower = clean.lowercased()
        for prefix in prefixesToRemove {
            if lower.hasPrefix(prefix) {
                let startIdx = clean.index(clean.startIndex, offsetBy: prefix.count)
                clean = String(clean[startIdx...])
                break
            }
        }
        
        clean = clean.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
        
        if clean.isEmpty {
            return query.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return clean
    }
    
    private func fetchWttrInJson(location: String, originalQuery: String) async -> WebSearchResult? {
        guard let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://wttr.in/\(encoded)?format=j1") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue("HomeAI-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            
            var weatherReport = ""
            var locationName = location
            
            // Extract nearest area
            if let nearestArea = (json["nearest_area"] as? [[String: Any]])?.first {
                let areaName = (nearestArea["areaName"] as? [[String: Any]])?.first?["value"] as? String ?? ""
                let region = (nearestArea["region"] as? [[String: Any]])?.first?["value"] as? String ?? ""
                let country = (nearestArea["country"] as? [[String: Any]])?.first?["value"] as? String ?? ""
                if !areaName.isEmpty {
                    locationName = "\(areaName)\(region.isEmpty ? "" : ", \(region)")\(country.isEmpty ? "" : ", \(country)")"
                }
            }
            
            // Extract current condition
            if let current = (json["current_condition"] as? [[String: Any]])?.first {
                let tempF = current["temp_F"] as? String ?? ""
                let tempC = current["temp_C"] as? String ?? ""
                let feelsLikeF = current["FeelsLikeF"] as? String ?? ""
                let feelsLikeC = current["FeelsLikeC"] as? String ?? ""
                let humidity = current["humidity"] as? String ?? ""
                let desc = (current["weatherDesc"] as? [[String: Any]])?.first?["value"] as? String ?? "Clear"
                let windSpeedMiles = current["windspeedMiles"] as? String ?? ""
                let windDir = current["winddir16Point"] as? String ?? ""
                let precipInches = current["precipInches"] as? String ?? "0.0"
                let uvIndex = current["uvIndex"] as? String ?? ""
                
                weatherReport += "Location: \(locationName)\n"
                weatherReport += "Condition: \(desc)\n"
                weatherReport += "Temperature: \(tempF)°F (\(tempC)°C)\n"
                weatherReport += "Feels Like: \(feelsLikeF)°F (\(feelsLikeC)°C)\n"
                weatherReport += "Humidity: \(humidity)%\n"
                weatherReport += "Wind: \(windSpeedMiles) mph \(windDir)\n"
                weatherReport += "Precipitation: \(precipInches) inches\n"
                if !uvIndex.isEmpty {
                    weatherReport += "UV Index: \(uvIndex)\n"
                }
            }
            
            // Extract 3-day forecast summary
            if let forecastDays = json["weather"] as? [[String: Any]] {
                weatherReport += "\nUpcoming Forecast:\n"
                for day in forecastDays.prefix(3) {
                    let date = day["date"] as? String ?? ""
                    let maxF = day["maxtempF"] as? String ?? ""
                    let minF = day["mintempF"] as? String ?? ""
                    let avgDesc = ((day["hourly"] as? [[String: Any]])?.first?["weatherDesc"] as? [[String: Any]])?.first?["value"] as? String ?? ""
                    weatherReport += "- \(date): High \(maxF)°F / Low \(minF)°F, \(avgDesc)\n"
                }
            }
            
            guard !weatherReport.isEmpty else { return nil }
            
            let timeString = Self.contextDateFormatter.string(from: Date())
            
            let formattedContext = """
            [Verified Real-Time Live Weather Information - Retrieved at \(timeString)]:
            \(weatherReport)
            
            Instruction: Use the verified live real-time meteorological data above to directly, accurately, and politely answer the user's weather question. You have full access to this live weather report. Do not state that you cannot access real-time data.
            """
            
            return WebSearchResult(
                query: originalQuery,
                formattedContext: formattedContext,
                summaryTitle: "Live Weather: \(locationName)",
                sourceURLs: ["https://wttr.in/\(encoded)"],
                isWeather: true
            )
        } catch {
            AppLogger.network.warning("wttr.in JSON fetch error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func fetchWttrInText(location: String, originalQuery: String) async -> WebSearchResult? {
        guard let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://wttr.in/\(encoded)?format=%l:+%c+%t+(feels+like+%f),+wind+%w,+humidity+%h,+condition:+%C") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue("HomeAI-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty, !text.contains("<html") else {
                return nil
            }
            
            let timeString = Self.contextDateFormatter.string(from: Date())
            
            let formattedContext = """
            [Verified Real-Time Live Weather Information - Retrieved at \(timeString)]:
            Current Weather Report:
            \(text)
            
            Instruction: Use the verified live real-time meteorological data above to directly and accurately answer the user's weather question. You have full access to this live weather data.
            """
            
            return WebSearchResult(
                query: originalQuery,
                formattedContext: formattedContext,
                summaryTitle: "Live Weather Report",
                sourceURLs: ["https://wttr.in/\(encoded)"],
                isWeather: true
            )
        } catch {
            AppLogger.network.warning("wttr.in text fetch error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func fetchOpenMeteoWeather(location: String, originalQuery: String) async -> WebSearchResult? {
        // Geocode location
        guard let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let geoURL = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1&language=en&format=json") else {
            return nil
        }
        
        do {
            let (data, _) = try await urlSession.data(from: geoURL)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let lat = first["latitude"] as? Double,
                  let lon = first["longitude"] as? Double else {
                return nil
            }
            
            let name = first["name"] as? String ?? location
            let admin1 = first["admin1"] as? String ?? ""
            
            // Fetch weather from open-meteo
            let weatherURLString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch&timezone=auto"
            guard let weatherURL = URL(string: weatherURLString) else { return nil }
            
            let (wData, _) = try await urlSession.data(from: weatherURL)
            guard let wJson = try JSONSerialization.jsonObject(with: wData) as? [String: Any],
                  let current = wJson["current"] as? [String: Any] else {
                return nil
            }
            
            let temp = current["temperature_2m"] as? Double ?? 0.0
            let feelsLike = current["apparent_temperature"] as? Double ?? temp
            let humidity = current["relative_humidity_2m"] as? Int ?? 0
            let windSpeed = current["wind_speed_10m"] as? Double ?? 0.0
            let precip = current["precipitation"] as? Double ?? 0.0
            
            let timeString = Self.contextDateFormatter.string(from: Date())
            
            let weatherReport = """
            Location: \(name), \(admin1) (Lat: \(lat), Lon: \(lon))
            Temperature: \(String(format: "%.1f", temp))°F
            Feels Like: \(String(format: "%.1f", feelsLike))°F
            Humidity: \(humidity)%
            Wind Speed: \(String(format: "%.1f", windSpeed)) mph
            Precipitation: \(String(format: "%.2f", precip)) inches
            """
            
            let formattedContext = """
            [Verified Real-Time Live Weather Information - Retrieved at \(timeString)]:
            \(weatherReport)
            
            Instruction: Use the verified live real-time meteorological data above to directly and accurately answer the user's weather question. You have full access to this live weather data.
            """
            
            return WebSearchResult(
                query: originalQuery,
                formattedContext: formattedContext,
                summaryTitle: "Live Weather: \(name), \(admin1)",
                sourceURLs: [weatherURLString],
                isWeather: true
            )
        } catch {
            return nil
        }
    }
    
    // MARK: - General Web Search
    
    public func performWebSearch(query: String) async -> WebSearchResult? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        // 1. DuckDuckGo HTML Search
        if let htmlResult = await fetchDuckDuckGoHtml(query: query, encoded: encoded) {
            return htmlResult
        }
        
        // 2. DuckDuckGo Instant Answer API
        if let instantResult = await fetchDuckDuckGoInstantAnswer(query: query, encoded: encoded) {
            return instantResult
        }
        
        return nil
    }
    
    private func fetchDuckDuckGoHtml(query: String, encoded: String) async -> WebSearchResult? {
        guard let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encoded)") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            let snippets = extractSnippetsFromDuckDuckGoHtml(html)
            guard !snippets.isEmpty else { return nil }
            
            let timeString = Self.contextDateFormatter.string(from: Date())
            
            var snippetText = ""
            for (index, snippet) in snippets.prefix(5).enumerated() {
                snippetText += "\(index + 1). \(snippet)\n\n"
            }
            
            let formattedContext = """
            [Real-Time Live Web Search Context - Retrieved at \(timeString)]:
            Query: "\(query)"
            
            Search Results & Findings:
            \(snippetText.trimmingCharacters(in: .whitespacesAndNewlines))
            
            Instruction: Use the above live real-time search findings to accurately, directly, and comprehensively answer the user's prompt. You have access to these up-to-date web results.
            """
            
            let cleanQ = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let badgeTitle = cleanQ.count > 25 ? "Web: \(cleanQ.prefix(22))..." : "Web: \(cleanQ)"
            
            return WebSearchResult(
                query: query,
                formattedContext: formattedContext,
                summaryTitle: badgeTitle,
                sourceURLs: ["https://duckduckgo.com/?q=\(encoded)"],
                isWeather: false
            )
        } catch {
            AppLogger.network.warning("DuckDuckGo HTML search error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func extractSnippetsFromDuckDuckGoHtml(_ html: String) -> [String] {
        var results: [String] = []
        
        // Regex to extract result snippets
        let pattern = "class=\"result__snippet\"[^>]*>(.*?)</a>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches {
                if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: html) {
                    let raw = String(html[range])
                    let cleaned = sanitizeHtml(raw)
                    if !cleaned.isEmpty && cleaned.count > 15 {
                        results.append(cleaned)
                    }
                }
            }
        }
        
        return results
    }
    
    private func fetchDuckDuckGoInstantAnswer(query: String, encoded: String) async -> WebSearchResult? {
        guard let url = URL(string: "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_redirect=1&no_html=1") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue("HomeAI-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            
            var facts: [String] = []
            if let abstract = json["AbstractText"] as? String, !abstract.isEmpty {
                facts.append(abstract)
            }
            if let answer = json["Answer"] as? String, !answer.isEmpty {
                facts.append(answer)
            }
            if let related = json["RelatedTopics"] as? [[String: Any]] {
                for item in related.prefix(3) {
                    if let text = item["Text"] as? String, !text.isEmpty {
                        facts.append(text)
                    }
                }
            }
            
            guard !facts.isEmpty else { return nil }
            
            let timeString = Self.contextDateFormatter.string(from: Date())
            
            let formatted = """
            [Real-Time Live Web Search Context - Retrieved at \(timeString)]:
            Query: "\(query)"
            
            Instant Answer Data:
            \(facts.joined(separator: "\n\n"))
            
            Instruction: Use the above live real-time information to answer the user's prompt directly and accurately.
            """
            
            let cleanQ = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let badgeTitle = cleanQ.count > 25 ? "Web: \(cleanQ.prefix(22))..." : "Web: \(cleanQ)"
            
            return WebSearchResult(
                query: query,
                formattedContext: formatted,
                summaryTitle: badgeTitle,
                sourceURLs: ["https://duckduckgo.com/?q=\(encoded)"],
                isWeather: false
            )
        } catch {
            return nil
        }
    }
    
    private func sanitizeHtml(_ html: String) -> String {
        var str = html
        // Remove HTML tags
        if let tagRegex = try? NSRegularExpression(pattern: "<[^>]+>") {
            str = tagRegex.stringByReplacingMatches(in: str, range: NSRange(str.startIndex..., in: str), withTemplate: "")
        }
        
        // Decode common HTML entities
        str = str.replacingOccurrences(of: "&amp;", with: "&")
        str = str.replacingOccurrences(of: "&lt;", with: "<")
        str = str.replacingOccurrences(of: "&gt;", with: ">")
        str = str.replacingOccurrences(of: "&quot;", with: "\"")
        str = str.replacingOccurrences(of: "&#39;", with: "'")
        str = str.replacingOccurrences(of: "&nbsp;", with: " ")
        
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
