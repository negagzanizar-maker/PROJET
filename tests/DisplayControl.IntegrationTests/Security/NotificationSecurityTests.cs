using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

using DisplayControl.Api.Notifications;
using DisplayControl.Api.Security;

namespace DisplayControl.IntegrationTests.Security;

public sealed class NotificationSecurityTests
{
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
    }
}
