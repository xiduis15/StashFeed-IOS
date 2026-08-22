// Overwritten on every build by project.yml's prebuildScripts ("Inject git commit hash") -
// don't hand-edit gitCommitHash, it won't survive the next build. This placeholder value is
// only what you'd see if that script somehow didn't run.
enum BuildInfo {
    static let gitCommitHash = "dev"
}
