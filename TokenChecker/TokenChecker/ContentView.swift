import SwiftUI

struct ContentView: View {
    @State private var owner = ""
    @State private var repo = ""
    @State private var token = ""
    @State private var showToken = false
    @State private var status = ""
    @State private var filePaths: [String] = []
    var body: some View {
        VStack(spacing: 0) {
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
                    .disabled(owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              repo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Text(status)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

            if !filePaths.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Files in default branch:")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(filePaths, id: \.self) { path in
                                Text(path)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 0, maxHeight: .infinity)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .onChange(of: owner) {
            status = ""
            filePaths = []
        }
        .onChange(of: repo) {
            status = ""
            filePaths = []
        }
        .onChange(of: token) {
            status = ""
            filePaths = []
        }
    }
    
    private func clear() {
        status = ""
        owner = ""
        repo = ""
        token = ""
        filePaths = []
    }
    
    private struct GitTreeEntry: Decodable {
        let path: String
        let type: String   // "blob", "tree", "commit"
    }

    private struct GitTreeResponse: Decodable {
        let tree: [GitTreeEntry]
        let truncated: Bool
    }

    private func fetchAllFiles(
        owner: String,
        repo: String,
        token: String
    ) async throws -> (paths: [String], truncated: Bool) {
        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/git/trees/HEAD?recursive=1"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "GitHubAPI",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"]
            )
        }

        let decoder = JSONDecoder()
        let treeResponse = try decoder.decode(GitTreeResponse.self, from: data)

        let files = treeResponse.tree
            .filter { $0.type == "blob" }
            .map { $0.path }

        return (files, treeResponse.truncated)
    }
    
    private func check() async {
        let trimmedOwner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRepo = repo.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        
        filePaths = []
        
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
                    let (paths, truncated) = try await fetchAllFiles(
                        owner: trimmedOwner,
                        repo: trimmedRepo,
                        token: trimmedToken
                    )
                    filePaths = paths.sorted()
                    if truncated {
                        status += "\n⚠️ GitHub tree is truncated; file list may be incomplete."
                    }
                } catch {
                    status += "\n⚠️ Failed to fetch file list: \(error.localizedDescription)"
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
