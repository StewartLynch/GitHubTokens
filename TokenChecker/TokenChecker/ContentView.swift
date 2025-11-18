//
//----------------------------------------------
// Original project: TokenChecker
//
// Follow me on Mastodon: https://iosdev.space/@StewartLynch
// Follow me on Threads: https://www.threads.net/@stewartlynch
// Follow me on Bluesky: https://bsky.app/profile/stewartlynch.bsky.social
// Follow me on X: https://x.com/StewartLynch
// Follow me on LinkedIn: https://linkedin.com/in/StewartLynch
// Email: slynch@createchsol.com
// Subscribe on YouTube: https://youTube.com/@StewartLynch
// Buy me a ko-fi:  https://ko-fi.com/StewartLynch
//----------------------------------------------
// Copyright © 2025 CreaTECH Solutions (Stewart Lynch). All rights reserved.


import SwiftUI

struct ContentView: View {
    @State private var owner = ""
    @State private var repo = ""
    @State private var token = ""
    @State private var showToken = false
    @State private var status = ""
    @State private var json: String? = nil
    var body: some View {
        VStack {
            Form {
                TextField("Owner", text: $owner)
                TextField("Repostiory", text: $repo)
                HStack {
                    if showToken {
                        TextField("Token", text: $token)
                    } else {
                        SecureField("Token", text: $token)
                    }
                    Button {
                        showToken.toggle()
                    } label: {
                        Image(systemName: showToken ? "eye.slash" : "eye")
                    }
                }
                HStack {
                    Button("Clear") {
                        clear()
                    }
                    Button("Verify") {
                        status = ""
                        Task {
                            await check()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || repo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            Text(status)
            if let json {
                ScrollView {
                    Text(json)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
            }
            Spacer()
        }
        .padding()
        .onChange(of: owner) {
            status = ""
            json = nil
        }
        .onChange(of: repo) {
            status = ""
            json = nil
        }
        .onChange(of: token) {
            status = ""
            json = nil
        }
    }
    
    private func clear() {
        status = ""
        owner = ""
        repo = ""
        token = ""
        json = nil
    }
    private func check() async {
        let trimmedOwner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRepo = repo.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let urlString = "https://api.github.com/repos/\(trimmedOwner)/\(trimmedRepo)"
        guard let url = URL(string: urlString) else {
            status = "Invalid URL: \(urlString)"
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                status = "No HTTP response."
                return
            }
            
            switch http.statusCode {
            case 200:
                status = "✅ Token HAS access to \(owner)/\(repo)"
                do {
                    let object = try JSONSerialization.jsonObject(with: data, options: [])
                    let prettyData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
                    json = String(data: prettyData, encoding: .utf8)
                } catch {
                    // Fallback to raw string if pretty printing fails
                    json = String(data: data, encoding: .utf8)
                }
                return
                
            case 404:
                status =
"""
🔒 404 Not Found.
   Either the repo does not exist OR the token does not have access.
"""
                return
                
            case 401:
                status = "❌ 401 Unauthorized. Token is invalid or missing."
                return
                
            case 403:
                status = "❌ 403 Forbidden. Token is valid but does not have permission."
                if let body = String(data: data, encoding: .utf8) {
                    status += "\nResponse: \(body)"
                }
                return
                
            default:
                status = "❌ Unexpected status code: \(http.statusCode)"
                if let body = String(data: data, encoding: .utf8) {
                    status += "Response: \(body)"
                }
                return
            }
        } catch {
            status = "❌ Request failed: \(error)"
            return
        }
    }
}

#Preview {
    ContentView()
}
