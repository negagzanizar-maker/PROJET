using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

using DisplayControl.Api.Notifications;
using DisplayControl.Api.Security;
using Microsoft.Extensions.Caching.Memory;

namespace DisplayControl.IntegrationTests.Security;

public sealed class NotificationSecurityTests
{
    [Fact]
    public void AuthenticationLimiterCombinesAttemptsByAccountKey()
    {
        using var cache = new MemoryCache(new MemoryCacheOptions { SizeLimit = 100 });
        var limiter = new AuthenticationAccountRateLimiter(cache);

        for (var attempt = 0; attempt < 10; attempt++)
        {
            Assert.True(limiter.TryAcquire("email:USER@EXAMPLE.TEST"));
        }

        Assert.False(limiter.TryAcquire("email:USER@EXAMPLE.TEST"));
        Assert.True(limiter.TryAcquire("email:OTHER@EXAMPLE.TEST"));
    }

    [Fact]
    public void PlatformBootstrapCredentialUsesOnlyTheConfiguredSha256Digest()
    {
        const string token = "one-time-bootstrap-token-with-entropy";
        var digest = Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
        var credential = new PlatformBootstrapCredential(digest);

        Assert.True(credential.Enabled);
        Assert.True(credential.Verify(token));
        Assert.False(credential.Verify("wrong-token"));
        Assert.False(new PlatformBootstrapCredential(null).Verify(token));
    }

    [Fact]
    public void PasswordResetMessageEncodesUntrustedQueryValuesAndHtmlAttribute()
    {
        var payload = JsonSerializer.Serialize(new { Token = "a&b?=" });
        var message = PasswordResetMessageFactory.Create(
            new Uri("https://display.example.test/"),
            "user+screen@example.test",
            payload);

        Assert.Contains("email=user%2Bscreen%40example.test", message.PlainText, StringComparison.Ordinal);
        Assert.Contains("token=a%26b%3F%3D", message.PlainText, StringComparison.Ordinal);
        Assert.Contains("&amp;token=a%26b%3F%3D", message.Html, StringComparison.Ordinal);
        Assert.DoesNotContain("a&b?=", message.Html, StringComparison.Ordinal);
        var resetLink = ExtractFirstUri(message.PlainText);
        Assert.Empty(resetLink.Query);
        Assert.StartsWith("#/reset-password?", resetLink.Fragment, StringComparison.Ordinal);
    }

    [Fact]
    public void InvitationTokenIsKeptInTheBrowserFragment()
    {
        var payload = JsonSerializer.Serialize(new { Token = "invitation-token-value" });
        var message = InvitationMessageFactory.Create(
            new Uri("https://display.example.test/"),
            "user@example.test",
            payload);

        var invitationLink = ExtractFirstUri(message.PlainText);
        Assert.Empty(invitationLink.Query);
        Assert.StartsWith("#/accept-invitation?token=", invitationLink.Fragment, StringComparison.Ordinal);
    }

    private static Uri ExtractFirstUri(string text)
    {
        var start = text.IndexOf("https://", StringComparison.Ordinal);
        Assert.True(start >= 0);
        var end = text.IndexOfAny([' ', '\r', '\n'], start);
        return new Uri(end < 0 ? text[start..] : text[start..end]);
    }
}
