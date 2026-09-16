import Foundation
import Combine

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [XtreamProfile] = []
    @Published var selectedProfileId: UUID?

    private let defaultsKey = "xtream.profiles"

    var selectedProfile: XtreamProfile? {
        profiles.first { $0.id == selectedProfileId }
    }

    init() {
        load()
        if selectedProfileId == nil {
            selectedProfileId = profiles.first?.id
        }
    }

    func password(for profile: XtreamProfile) -> String {
        profile.password
    }

    func addProfile(name: String, serverURL: String, username: String, password: String) {
        let profile = XtreamProfile(name: name, serverURL: serverURL, username: username, password: password)
        profiles.append(profile)
        save()
        if selectedProfileId == nil {
            selectedProfileId = profile.id
        }
    }

    func updateProfile(_ profile: XtreamProfile, name: String, serverURL: String, username: String, password: String) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index].name = name
        profiles[index].serverURL = serverURL
        profiles[index].username = username
        profiles[index].password = password
        save()
    }

    func removeProfile(_ profile: XtreamProfile) {
        profiles.removeAll { $0.id == profile.id }
        save()
        if selectedProfileId == profile.id {
            selectedProfileId = profiles.first?.id
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        profiles = (try? JSONDecoder().decode([XtreamProfile].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
