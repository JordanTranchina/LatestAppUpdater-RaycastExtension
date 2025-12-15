import { List, ActionPanel, Action, showToast, Toast, Icon } from "@raycast/api";
import { useExec } from "@raycast/utils";
import { existsSync } from "fs";

// Path to the CLI inside the Latest app bundle
const CLI_PATH = "/Applications/Latest.app/Contents/MacOS/latest-cli";

// Interface for app update data from CLI
interface AppUpdate {
  id: string;
  name: string;
  installedVersion: string;
  availableVersion: string;
  source: "appstore" | "sparkle" | "homebrew" | "direct";
  changelog?: string;
  canInstall: boolean;
}

export default function CheckUpdates() {
  // Check if Latest app and CLI are installed
  const latestAppPath = "/Applications/Latest.app";
  const cliExists = existsSync(CLI_PATH);
  const appExists = existsSync(latestAppPath);

  // For now, show placeholder since CLI doesn't exist yet
  if (!appExists) {
    return (
      <List>
        <List.EmptyView
          icon={Icon.Download}
          title="Latest App Not Installed"
          description="Install the Latest app to check for updates"
          actions={
            <ActionPanel>
              <Action.OpenInBrowser title="Download Latest" url="https://max.codes/latest" />
            </ActionPanel>
          }
        />
      </List>
    );
  }

  if (!cliExists) {
    return (
      <List>
        <List.EmptyView
          icon={Icon.Hammer}
          title="CLI Helper Not Found"
          description="The latest-cli helper is not yet available. This is expected during development."
          actions={
            <ActionPanel>
              <Action.Open title="Open Latest App" target={latestAppPath} />
            </ActionPanel>
          }
        />
      </List>
    );
  }

  // Once CLI exists, this will work:
  // const { data, isLoading, error } = useExec(CLI_PATH, ["list", "--json"]);

  return (
    <List>
      <List.EmptyView
        icon={Icon.CheckCircle}
        title="Ready for CLI Integration"
        description="The extension scaffold is complete. Next: build the latest-cli helper."
      />
    </List>
  );
}
