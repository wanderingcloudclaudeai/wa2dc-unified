// Channel reordering ("bump active chats to the top of their category").
//
// Ported from sabaris-sps/wa2dc and hardened for wa2dc-unified:
//  - never awaited on the message hot path (callers fire-and-forget),
//  - per-channel cooldown so busy chats cannot queue up Discord's strict
//    channel-update rate limit (2 updates / 10 minutes / channel),
//  - threads and forum posts are skipped because they have no position.

const DEFAULT_COOLDOWN_MS = 10 * 60 * 1000;
const MAX_TRACKED_CHANNELS = 2048;

export const createChannelReorderer = ({
	fetchChannel,
	isEnabled,
	logger = () => null,
	cooldownMs = DEFAULT_COOLDOWN_MS,
	now = Date.now,
} = {}) => {
	const lastAttemptAt = new Map();

	const remember = (channelId, at) => {
		lastAttemptAt.delete(channelId);
		lastAttemptAt.set(channelId, at);
		if (lastAttemptAt.size > MAX_TRACKED_CHANNELS) {
			lastAttemptAt.delete(lastAttemptAt.keys().next().value);
		}
	};

	const moveChannelToTop = async (channelId) => {
		if (!channelId || !isEnabled?.()) return false;
		const at = now();
		const previous = lastAttemptAt.get(channelId);
		if (previous != null && at - previous < cooldownMs) return false;

		try {
			const channel = await fetchChannel(channelId);
			if (!channel || typeof channel.setPosition !== "function") return false;
			if (typeof channel.isThread === "function" && channel.isThread()) {
				return false;
			}
			if (channel.position === 0) return false;
			// Claim the cooldown before the request so concurrent messages in the
			// same chat produce a single API call.
			remember(channelId, at);
			await channel.setPosition(0, { reason: "Active WhatsApp chat" });
			return true;
		} catch (err) {
			logger()?.debug?.(
				{ err, channelId },
				"Failed or rate-limited while moving channel to top",
			);
			return false;
		}
	};

	return { moveChannelToTop, reset: () => lastAttemptAt.clear() };
};
