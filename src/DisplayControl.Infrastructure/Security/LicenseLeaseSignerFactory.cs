using System.Security.Cryptography;

namespace DisplayControl.Infrastructure.Security;

public static class LicenseLeaseSignerFactory
{
    public static EcdsaLicenseLeaseSigner LoadFileBacked(string privateKeyPath, string password)
    {
        if (string.IsNullOrWhiteSpace(privateKeyPath) || !Path.IsPathFullyQualified(privateKeyPath))
        {
            throw new InvalidOperationException("The licence signing key path must be absolute.");
        }

        if (string.IsNullOrEmpty(password))
        {
            throw new InvalidOperationException("The licence signing key password is required.");
        }

        var fullPath = Path.GetFullPath(privateKeyPath);
        var file = new FileInfo(fullPath);
        if (!file.Exists || file.LinkTarget is not null || file.Attributes.HasFlag(FileAttributes.ReparsePoint))
        {
            throw new InvalidOperationException("The licence signing key file is missing or is a reparse point.");
        }

        var privateKey = ECDsa.Create();
        try
        {
            privateKey.ImportFromEncryptedPem(File.ReadAllText(fullPath), password);
            return new EcdsaLicenseLeaseSigner(privateKey);
        }
        catch
        {
            privateKey.Dispose();
            throw;
        }
    }

    public static EcdsaLicenseLeaseSigner CreateEphemeralForTesting() =>
        new(ECDsa.Create(ECCurve.NamedCurves.nistP256));
}
