// fleet-api.ts — how a machine talks to fleet-api: fleet-api's generated TypeScript SDK, and nothing
// written here. The report's shape, its checks and the routes are the SDK's, made from fleet-api's
// contract; report.nu builds the report and keeps the spool.
//
//   bun tasks/fleet-api.ts check  < report.json   does fleet-api's schema take it? posts nothing
//   bun tasks/fleet-api.ts report < report.json   check it, then post it with the machine's Access token
//   bun tasks/fleet-api.ts list                   the fleet, with the same token
//
// The machine's Cloudflare Access service token is FLEET_API_ACCESS_CLIENT_ID and
// FLEET_API_ACCESS_CLIENT_SECRET (report.nu takes them from the environment or the machine's file).
// FLEET_API_SDK is the SDK's folder (report.nu finds it with mise: the tool list installs it from
// fleet-api's release). FLEET_API_URL, if set, is where fleet-api is; otherwise the SDK's default.
// It prints one JSON object, {"ok": true, "answer": ...} or {"ok": false, "retry": ..., "why": ...},
// and exits 0 when ok, 1 when the report is refused for good, 2 when it is worth trying again.
import { join } from "node:path";
import { pathToFileURL } from "node:url";

function done(result: object, code: number): never {
  console.log(JSON.stringify(result));
  process.exit(code);
}
const fail = (why: string, retry: boolean): never => done({ ok: false, retry, why }, retry ? 2 : 1);

const command = process.argv[2];
if (!["check", "report", "list"].includes(command ?? "")) fail("usage: bun tasks/fleet-api.ts check|report|list", false);

const dir = process.env.FLEET_API_SDK ?? "";
if (dir === "") fail("fleet-api's SDK is not installed: mise install (the tool list has github:joeblew999/fleet-api)", true);
const { FleetClient, FleetEnvironment, FleetError, FleetTimeoutError, serialization } = await import(pathToFileURL(join(dir, "index.ts")).href);

// The report on stdin, checked against fleet-api's schema: types, enums and required fields. The
// Worker checks the rest (bounds, and the rules between fields) and answers 422.
async function checked() {
  let json: unknown;
  try {
    json = JSON.parse(await Bun.stdin.text());
  } catch {
    return fail("not JSON", false);
  }
  const parsed = serialization.DeviceReport.parse(json);
  if (!parsed.ok) {
    const errors = parsed.errors.map((e: { path: string[]; message: string }) => `${e.path.join(".") || "report"}: ${e.message}`);
    return fail(`not a report fleet-api takes: ${errors.join("; ")}`, false);
  }
  return parsed.value;
}

// The client, as fleet-api's own live test makes it (fleet-api's test/sdk-live-test.mjs). The SDK
// should send both Access headers from FLEET_API_ACCESS_CLIENT_ID and _SECRET by itself, but its
// generated auth sends only one of the two, so it is given them as headers with its own auth off.
// Upstream: fern-api/fern#17775 (when fixed: new FleetClient({ baseUrl, maxRetries: 0, ... }), the variables doing the rest)
function client() {
  const id = process.env.FLEET_API_ACCESS_CLIENT_ID ?? "";
  const hidden = process.env.FLEET_API_ACCESS_CLIENT_SECRET ?? "";
  if (id === "" || hidden === "") return fail("no Access token", true);
  // One try each: report.nu's spool is the retry.
  return new FleetClient({
    baseUrl: process.env.FLEET_API_URL || FleetEnvironment.Default.base,
    maxRetries: 0,
    timeoutInSeconds: 15,
    auth: false,
    headers: { "CF-Access-Client-Id": id, "CF-Access-Client-Secret": hidden },
  });
}

// What went wrong, and whether trying again later can help: not when fleet-api refused what was sent.
function failed(error: unknown): never {
  if (error instanceof FleetTimeoutError) fail("fleet-api did not answer in 15 s", true);
  if (error instanceof FleetError) {
    const status = error.statusCode;
    if (status === undefined) fail(`could not reach fleet-api: ${error.message}`, true);
    if (status === 401 || status === 403) fail(`fleet-api refused the token (${status})`, true);
    if (status === 408 || status === 429 || status >= 500) fail(`fleet-api answered ${status}`, true);
    const errors = (error.body as { errors?: { location?: string; message?: string }[] })?.errors ?? [];
    fail(`fleet-api refused it (${status}) ${errors.map(e => `${e.location} ${e.message}`).join("; ")}`.trim(), false);
  }
  fail(`could not reach fleet-api: ${error instanceof Error ? error.message : String(error)}`, true);
}

if (command === "check") {
  const report = await checked();
  done({ ok: true, answer: { id: report.id } }, 0);
}
if (command === "report") {
  const report = await checked();
  const fleet = client();
  try {
    const posted = await fleet.devices.report({ id: report.id, body: report });
    done({ ok: true, answer: serialization.DevicePosted.jsonOrThrow(posted, { unrecognizedObjectKeys: "passthrough" }) }, 0);
  } catch (error) {
    failed(error);
  }
}
if (command === "list") {
  const fleet = client();
  try {
    const list = await fleet.devices.list();
    done({ ok: true, answer: serialization.DeviceList.jsonOrThrow(list, { unrecognizedObjectKeys: "passthrough" }) }, 0);
  } catch (error) {
    failed(error);
  }
}
