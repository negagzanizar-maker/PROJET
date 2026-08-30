using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DisplayControl.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class HeartbeatBootIdempotency : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ux_device_heartbeats_device_sequence",
                schema: "app",
                table: "device_heartbeats");

            migrationBuilder.AddColumn<Guid>(
                name: "boot_id",
                schema: "app",
                table: "device_heartbeats",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.AddColumn<byte[]>(
                name: "request_sha256",
                schema: "app",
                table: "device_heartbeats",
                type: "bytea",
                nullable: false,
                defaultValue: new byte[0]);

            migrationBuilder.AddColumn<string>(
                name: "response_json",
                schema: "app",
                table: "device_heartbeats",
                type: "jsonb",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "ux_device_heartbeats_device_boot_sequence",
                schema: "app",
                table: "device_heartbeats",
                columns: new[] { "tenant_id", "device_id", "boot_id", "sequence" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ux_device_heartbeats_device_boot_sequence",
                schema: "app",
                table: "device_heartbeats");

            migrationBuilder.DropColumn(
                name: "boot_id",
                schema: "app",
                table: "device_heartbeats");

            migrationBuilder.DropColumn(
                name: "request_sha256",
                schema: "app",
                table: "device_heartbeats");

            migrationBuilder.DropColumn(
                name: "response_json",
                schema: "app",
                table: "device_heartbeats");

            migrationBuilder.CreateIndex(
                name: "ux_device_heartbeats_device_sequence",
                schema: "app",
                table: "device_heartbeats",
                columns: new[] { "tenant_id", "device_id", "sequence" },
                unique: true);
        }
    }
}
