import "server-only";
import { randomUUID } from "node:crypto";

type AnalyticsProperty = string | number | boolean;
type AnalyticsProperties = Record<string, AnalyticsProperty>;

const postHogToken = process.env.POSTHOG_PROJECT_TOKEN?.trim();
const postHogHost = (process.env.POSTHOG_HOST?.trim() || "https://us.i.posthog.com").replace(/\/+$/, "");

export async function captureAnonymousEvent(
  event: string,
  properties: AnalyticsProperties,
): Promise<boolean> {
  if (!postHogToken) {
    console.info("analytics.not_configured", { event, ...properties });
    return false;
  }

  try {
    const response = await fetch(`${postHogHost}/i/v0/e/`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        api_key: postHogToken,
        event,
        distinct_id: `anonymous-${randomUUID()}`,
        properties: {
          ...properties,
          $process_person_profile: false,
          $lib: "tokenout-server",
        },
      }),
      cache: "no-store",
      signal: AbortSignal.timeout(4_000),
    });

    if (!response.ok) {
      console.error("analytics.capture_failed", { event, status: response.status });
      return false;
    }

    return true;
  } catch (error) {
    console.error("analytics.capture_failed", { event, error });
    return false;
  }
}
