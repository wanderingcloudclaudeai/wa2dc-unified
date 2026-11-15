package config

import (
	"github.com/caarlos0/env/v11"
)

type HummusConfig struct {
	DiscordBotToken  string `env:"DISCORD_BOT_TOKEN"`
	WhatsappGoUAEJID string `env:"WA_GOUAE_JID"`
	// WhatsappChatJID is the project-neutral name for the same setting
	// (added in wa2dc-unified); it wins over WA_GOUAE_JID when both are set.
	WhatsappChatJID     string `env:"WA_CHAT_JID"`
	DiscordWebhookID    string `env:"DISCORD_WEBHOOK_ID"`
	DiscordWebhoolToken string `env:"DISCORD_WEBHOOK_TOKEN"`
	FallbackAvatarURL   string `env:"DISCORD_FALLBACK_AVATAR_URL"`
	// DiscordChannelID    string `env:"DISCORD_CHANNEL_ID"`
}

func LoadFromEnv() (HummusConfig, error) {
	var hummusConfig HummusConfig
	err := env.Parse(&hummusConfig)

	if hummusConfig.WhatsappChatJID != "" {
		hummusConfig.WhatsappGoUAEJID = hummusConfig.WhatsappChatJID
	}

	return hummusConfig, err
}
