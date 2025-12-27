import { List, ActionPanel, Action, Icon, environment, Color, showToast, Toast, confirmAlert } from "@raycast/api";
import { useExec } from "@raycast/utils";
import { existsSync } from "fs";
import { join } from "path";
import { exec } from "child_process";
import React from "react";

// Path to the CLI bundled in the extension assets
const CLI_PATH = join(environment.assetsPath, "latest-cli");
// ... (omitting interface for brevity, but it's there)

// Interface for app info from CLI
interface CLIAppInfo {
  id: string;
  name: string;
  installedVersion: string;
  source: string;
  availableVersion: string | null;
  changelog: string | null;
  canInstall: boolean;
}

export default function CheckUpdates() {
  const cliExists = existsSync(CLI_PATH);

  const { data, isLoading, error, revalidate } = useExec(CLI_PATH, ["list", "--json"], {
    execute: cliExists,
  });

  if (!cliExists) {
    return (
      <List>
        <List.EmptyView
          icon={Icon.Hammer}
          title="CLI Helper Not Found"
          description="The latest-cli helper is missing. Run ./build_cli.sh to build and bundle it."
        />
      </List>
    );
  }

  async function installApp(app: CLIAppInfo) {
    if (await confirmAlert({ title: `Install update for ${app.name}?` })) {
      const toast = await showToast({
        style: Toast.Style.Animated,
        title: "Installing Update",
        message: app.name,
      });

      exec(`${CLI_PATH} install --id ${app.id} --json-stream`, (error, stdout, stderr) => {
        if (error) {
          toast.style = Toast.Style.Failure;
          toast.title = "Installation Failed";
          toast.message = error.message;
          return;
        }
        
        // Final state from stdout
        try {
           const lines = stdout.trim().split("\n");
           const finalStatus = JSON.parse(lines[lines.length - 1]);
           if (finalStatus.state === "error") {
             toast.style = Toast.Style.Failure;
             toast.title = "Installation Failed";
             toast.message = finalStatus.message;
           } else {
             toast.style = Toast.Style.Success;
             toast.title = "Installed Successfully";
             toast.message = `${app.name} has been updated.`;
             revalidate();
           }
        } catch (e) {
          toast.style = Toast.Style.Success;
          toast.title = "Installation Finished";
          revalidate();
        }
      });
    }
  }

  if (error) {
    return (
      <List>
        <List.EmptyView
          icon={Icon.Warning}
          title="Execution Error"
          description={error.message}
        />
      </List>
    );
  }

  const apps: CLIAppInfo[] = data ? JSON.parse(data) : [];
  
  // Sort: apps with updates first
  const sortedApps = [...apps].sort((a, b) => {
    if (a.availableVersion && !b.availableVersion) return -1;
    if (!a.availableVersion && b.availableVersion) return 1;
    return a.name.localeCompare(b.name);
  });

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search apps...">
      {sortedApps.map((app) => {
        const hasUpdate = app.availableVersion && app.availableVersion !== app.installedVersion;
        
        return (
          <List.Item
            key={app.id}
            title={app.name}
            subtitle={app.id}
            icon={{ fileIcon: `/Applications/${app.name}.app` }}
            accessories={[
              { 
                text: { 
                  value: hasUpdate ? `↑ ${app.availableVersion}` : app.installedVersion, 
                  color: hasUpdate ? Color.Orange : undefined 
                },
                tooltip: hasUpdate ? `Update Available: ${app.availableVersion}` : `Up to Date: ${app.installedVersion}` 
              },
              { tag: { value: app.source, color: getSourceColor(app.source) }, tooltip: "Update Source" },
            ]}
            actions={
              <ActionPanel>
                {hasUpdate && (
                  <Action
                    title="Install Update"
                    icon={Icon.Download}
                    onAction={() => installApp(app)}
                  />
                )}
                <Action.OpenInBrowser
                  title="Open in Finder"
                  url={`file:///Applications/${app.name}.app`}
                  icon={Icon.Finder}
                />
                <Action.CopyToClipboard title="Copy ID" content={app.id} />
              </ActionPanel>
            }
          />
        );
      })}
    </List>
  );
}

function getSourceColor(source: string) {
  switch (source.toLowerCase()) {
    case "appstore": return "blue";
    case "homebrew": return "orange";
    case "sparkle": return "purple";
    default: return undefined;
  }
}
