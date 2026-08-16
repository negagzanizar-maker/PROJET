CREATE TABLE IF NOT EXISTS "__EFMigrationsHistory" (
    "MigrationId" character varying(150) NOT NULL,
    "ProductVersion" character varying(32) NOT NULL,
    CONSTRAINT "PK___EFMigrationsHistory" PRIMARY KEY ("MigrationId")
);

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815150501_InitialPlatformSchema') THEN
        IF NOT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = 'app') THEN
            CREATE SCHEMA app;
        END IF;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815150501_InitialPlatformSchema') THEN
    CREATE TABLE app.tenants (
        id uuid NOT NULL,
        name character varying(160) NOT NULL,
        slug character varying(80) NOT NULL,
        time_zone character varying(80) NOT NULL,
        state character varying(24) NOT NULL,
        created_at_utc timestamp with time zone NOT NULL,
        updated_at_utc timestamp with time zone NOT NULL,
        concurrency_token uuid NOT NULL,
        CONSTRAINT pk_tenants PRIMARY KEY (id)
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815150501_InitialPlatformSchema') THEN
    CREATE TABLE app.audit_events (
        id uuid NOT NULL,
        actor_type character varying(32) NOT NULL,
        actor_id uuid,
        action character varying(128) NOT NULL,
        target_type character varying(64) NOT NULL,
        target_id uuid,
        outcome character varying(32) NOT NULL,
        reason_code character varying(64),
        correlation_id uuid NOT NULL,
        details_json jsonb NOT NULL,
        occurred_at_utc timestamp with time zone NOT NULL,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_audit_events PRIMARY KEY (id),
        CONSTRAINT ak_audit_events_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT fk_audit_events_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815150501_InitialPlatformSchema') THEN
    CREATE TABLE app.devices (
        id uuid NOT NULL,
        display_name character varying(160) NOT NULL,
        state character varying(32) NOT NULL,
        serial_number_normalized character varying(32),
        hostname character varying(253),
        os_description character varying(256),
        architecture character varying(32),
        agent_version character varying(64),
        player_version character varying(64),
        disk_capacity_bytes bigint,
        last_seen_utc timestamp with time zone,
        applied_manifest_version bigint,
        playback_health_code character varying(64),
        created_at_utc timestamp with time zone NOT NULL,
        updated_at_utc timestamp with time zone NOT NULL,
        concurrency_token uuid NOT NULL,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_devices PRIMARY KEY (id),
        CONSTRAINT ak_devices_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT fk_devices_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815150501_InitialPlatformSchema') THEN
    CREATE TABLE app.outbox_messages (
        id uuid NOT NULL,
        message_type character varying(160) NOT NULL,
        payload_json jsonb NOT NULL,
        occurred_at_utc timestamp with time zone NOT NULL,
        processed_at_utc timestamp with time zone,
        attempt_count integer NOT NULL,
        last_safe_error character varying(1024),
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_outbox_messages PRIMARY KEY (id),
        CONSTRAINT ak_outbox_messages_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT fk_outbox_messages_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815150501_InitialPlatformSchema') THEN
    CREATE TABLE app.licenses (
        id uuid NOT NULL,
        device_id uuid NOT NULL,
        valid_from_utc timestamp with time zone NOT NULL,
        expires_at_utc timestamp with time zone NOT NULL,
        control_state character varying(32) NOT NULL,
        latest_issued_lease_expiry_utc timestamp with time zone,
        transfer_destination_device_id uuid,
        created_at_utc timestamp with time zone NOT NULL,
        updated_at_utc timestamp with time zone NOT NULL,
        concurrency_token uuid NOT NULL,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_licenses PRIMARY KEY (id),
        CONSTRAINT ak_licenses_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT ck_licenses_window CHECK (expires_at_utc > valid_from_utc),
        CONSTRAINT fk_licenses_devices_tenant FOREIGN KEY (tenant_id, device_id) REFERENCES app.devices (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_licenses_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815150501_InitialPlatformSchema') THEN
    CREATE INDEX ix_audit_events_tenant_occurred ON app.audit_events (tenant_id, occurred_at_utc);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815150501_InitialPlatformSchema') THEN
    CREATE UNIQUE INDEX ux_devices_tenant_serial ON app.devices (tenant_id, serial_number_normalized) WHERE serial_number_normalized IS NOT NULL;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815150501_InitialPlatformSchema') THEN
    CREATE INDEX ix_licenses_tenant_device ON app.licenses (tenant_id, device_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815150501_InitialPlatformSchema') THEN
    CREATE INDEX ix_outbox_pending ON app.outbox_messages (processed_at_utc, occurred_at_utc);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815150501_InitialPlatformSchema') THEN
    CREATE UNIQUE INDEX ux_tenants_slug ON app.tenants (slug);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815150501_InitialPlatformSchema') THEN
    ALTER TABLE app.tenants ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.tenants FORCE ROW LEVEL SECURITY;
    CREATE POLICY tenants_tenant_isolation ON app.tenants
        USING (id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.devices ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.devices FORCE ROW LEVEL SECURITY;
    CREATE POLICY devices_tenant_isolation ON app.devices
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.licenses ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.licenses FORCE ROW LEVEL SECURITY;
    CREATE POLICY licenses_tenant_isolation ON app.licenses
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.audit_events ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.audit_events FORCE ROW LEVEL SECURITY;
    CREATE POLICY audit_events_tenant_isolation ON app.audit_events
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.outbox_messages ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.outbox_messages FORCE ROW LEVEL SECURITY;
    CREATE POLICY outbox_messages_tenant_isolation ON app.outbox_messages
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815150501_InitialPlatformSchema') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260815150501_InitialPlatformSchema', '10.0.7');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815151241_AlignProviderModel') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260815151241_AlignProviderModel', '10.0.7');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE TABLE app.content_assets (
        id uuid NOT NULL,
        title character varying(200) NOT NULL,
        description character varying(2000),
        media_kind character varying(24) NOT NULL,
        lifecycle_state character varying(24) NOT NULL,
        created_by_user_id uuid NOT NULL,
        created_at_utc timestamp with time zone NOT NULL,
        updated_at_utc timestamp with time zone NOT NULL,
        archived_at_utc timestamp with time zone,
        concurrency_token uuid NOT NULL,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_content_assets PRIMARY KEY (id),
        CONSTRAINT ak_content_assets_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT fk_content_assets_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE TABLE app.device_groups (
        id uuid NOT NULL,
        name character varying(160) NOT NULL,
        description character varying(2000),
        created_by_user_id uuid NOT NULL,
        created_at_utc timestamp with time zone NOT NULL,
        updated_at_utc timestamp with time zone NOT NULL,
        concurrency_token uuid NOT NULL,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_device_groups PRIMARY KEY (id),
        CONSTRAINT ak_device_groups_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT fk_device_groups_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE TABLE app.license_events (
        id uuid NOT NULL,
        license_id uuid NOT NULL,
        event_type character varying(32) NOT NULL,
        actor_type character varying(32) NOT NULL,
        actor_id uuid,
        reason character varying(1000) NOT NULL,
        before_json jsonb NOT NULL,
        after_json jsonb NOT NULL,
        source_device_id uuid,
        destination_device_id uuid,
        occurred_at_utc timestamp with time zone NOT NULL,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_license_events PRIMARY KEY (id),
        CONSTRAINT ak_license_events_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT fk_license_events_licenses_tenant FOREIGN KEY (tenant_id, license_id) REFERENCES app.licenses (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_license_events_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE TABLE app.playlists (
        id uuid NOT NULL,
        name character varying(200) NOT NULL,
        description character varying(2000),
        created_by_user_id uuid NOT NULL,
        created_at_utc timestamp with time zone NOT NULL,
        updated_at_utc timestamp with time zone NOT NULL,
        archived_at_utc timestamp with time zone,
        concurrency_token uuid NOT NULL,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_playlists PRIMARY KEY (id),
        CONSTRAINT ak_playlists_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT fk_playlists_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE TABLE app.system_key_metadata (
        key_id character varying(128) NOT NULL,
        algorithm character varying(24) NOT NULL,
        purpose character varying(32) NOT NULL,
        public_key_der bytea NOT NULL,
        activates_at_utc timestamp with time zone NOT NULL,
        retires_at_utc timestamp with time zone,
        created_at_utc timestamp with time zone NOT NULL,
        CONSTRAINT pk_system_key_metadata PRIMARY KEY (key_id)
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE TABLE app.content_versions (
        id uuid NOT NULL,
        content_asset_id uuid NOT NULL,
        version_number integer NOT NULL,
        storage_key character varying(512) NOT NULL,
        byte_length bigint NOT NULL,
        sha256 bytea NOT NULL,
        detected_mime_type character varying(128) NOT NULL,
        original_display_file_name character varying(255) NOT NULL,
        media_metadata_json jsonb NOT NULL,
        scan_state character varying(32) NOT NULL,
        scan_engine_version character varying(128),
        rejection_code character varying(64),
        created_by_user_id uuid NOT NULL,
        created_at_utc timestamp with time zone NOT NULL,
        approved_by_user_id uuid,
        approved_at_utc timestamp with time zone,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_content_versions PRIMARY KEY (id),
        CONSTRAINT ak_content_versions_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT ck_content_versions_byte_length CHECK (byte_length >= 0),
        CONSTRAINT ck_content_versions_sha256 CHECK (octet_length(sha256) = 32),
        CONSTRAINT ck_content_versions_version CHECK (version_number > 0),
        CONSTRAINT fk_content_versions_assets_tenant FOREIGN KEY (tenant_id, content_asset_id) REFERENCES app.content_assets (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_content_versions_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE TABLE app.device_group_members (
        id uuid NOT NULL,
        device_group_id uuid NOT NULL,
        device_id uuid NOT NULL,
        added_by_user_id uuid NOT NULL,
        added_at_utc timestamp with time zone NOT NULL,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_device_group_members PRIMARY KEY (id),
        CONSTRAINT ak_device_group_members_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT fk_device_group_members_devices_tenant FOREIGN KEY (tenant_id, device_id) REFERENCES app.devices (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_device_group_members_groups_tenant FOREIGN KEY (tenant_id, device_group_id) REFERENCES app.device_groups (tenant_id, id) ON DELETE CASCADE,
        CONSTRAINT fk_device_group_members_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE TABLE app.playlist_versions (
        id uuid NOT NULL,
        playlist_id uuid NOT NULL,
        version_number integer NOT NULL,
        name_snapshot character varying(200) NOT NULL,
        description_snapshot character varying(2000),
        publication_state character varying(32) NOT NULL,
        created_by_user_id uuid NOT NULL,
        created_at_utc timestamp with time zone NOT NULL,
        published_by_user_id uuid,
        published_at_utc timestamp with time zone,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_playlist_versions PRIMARY KEY (id),
        CONSTRAINT ak_playlist_versions_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT ck_playlist_versions_version CHECK (version_number > 0),
        CONSTRAINT fk_playlist_versions_playlists_tenant FOREIGN KEY (tenant_id, playlist_id) REFERENCES app.playlists (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_playlist_versions_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE TABLE app.device_assignments (
        id uuid NOT NULL,
        device_id uuid NOT NULL,
        playlist_version_id uuid NOT NULL,
        is_enabled boolean NOT NULL,
        priority integer NOT NULL,
        starts_at_utc timestamp with time zone,
        ends_at_utc timestamp with time zone,
        presentation_time_zone character varying(80) NOT NULL,
        published_by_user_id uuid NOT NULL,
        published_at_utc timestamp with time zone NOT NULL,
        concurrency_token uuid NOT NULL,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_device_assignments PRIMARY KEY (id),
        CONSTRAINT ak_device_assignments_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT ck_device_assignments_window CHECK (starts_at_utc IS NULL OR ends_at_utc IS NULL OR ends_at_utc > starts_at_utc),
        CONSTRAINT fk_device_assignments_devices_tenant FOREIGN KEY (tenant_id, device_id) REFERENCES app.devices (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_device_assignments_playlist_versions_tenant FOREIGN KEY (tenant_id, playlist_version_id) REFERENCES app.playlist_versions (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_device_assignments_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE TABLE app.group_assignments (
        id uuid NOT NULL,
        device_group_id uuid NOT NULL,
        playlist_version_id uuid NOT NULL,
        is_enabled boolean NOT NULL,
        priority integer NOT NULL,
        starts_at_utc timestamp with time zone,
        ends_at_utc timestamp with time zone,
        presentation_time_zone character varying(80) NOT NULL,
        published_by_user_id uuid NOT NULL,
        published_at_utc timestamp with time zone NOT NULL,
        concurrency_token uuid NOT NULL,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_group_assignments PRIMARY KEY (id),
        CONSTRAINT ak_group_assignments_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT ck_group_assignments_window CHECK (starts_at_utc IS NULL OR ends_at_utc IS NULL OR ends_at_utc > starts_at_utc),
        CONSTRAINT fk_group_assignments_groups_tenant FOREIGN KEY (tenant_id, device_group_id) REFERENCES app.device_groups (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_group_assignments_playlist_versions_tenant FOREIGN KEY (tenant_id, playlist_version_id) REFERENCES app.playlist_versions (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_group_assignments_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE TABLE app.playlist_items (
        id uuid NOT NULL,
        playlist_version_id uuid NOT NULL,
        content_version_id uuid NOT NULL,
        position integer NOT NULL,
        duration_milliseconds integer,
        loop_video boolean NOT NULL,
        presentation_json jsonb NOT NULL,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_playlist_items PRIMARY KEY (id),
        CONSTRAINT ak_playlist_items_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT ck_playlist_items_duration CHECK (duration_milliseconds IS NULL OR duration_milliseconds > 0),
        CONSTRAINT ck_playlist_items_position CHECK (position >= 0),
        CONSTRAINT fk_playlist_items_content_versions_tenant FOREIGN KEY (tenant_id, content_version_id) REFERENCES app.content_versions (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_playlist_items_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT,
        CONSTRAINT fk_playlist_items_versions_tenant FOREIGN KEY (tenant_id, playlist_version_id) REFERENCES app.playlist_versions (tenant_id, id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE TABLE app.desired_states (
        id uuid NOT NULL,
        device_id uuid NOT NULL,
        version bigint NOT NULL,
        source_device_assignment_id uuid,
        source_group_assignment_id uuid,
        starts_at_utc timestamp with time zone,
        ends_at_utc timestamp with time zone,
        manifest_sha256 bytea NOT NULL,
        created_at_utc timestamp with time zone NOT NULL,
        published_at_utc timestamp with time zone NOT NULL,
        superseded_by_desired_state_id uuid,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_desired_states PRIMARY KEY (id),
        CONSTRAINT ak_desired_states_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT ck_desired_states_sha256 CHECK (octet_length(manifest_sha256) = 32),
        CONSTRAINT ck_desired_states_source CHECK ((source_device_assignment_id IS NOT NULL AND source_group_assignment_id IS NULL) OR (source_device_assignment_id IS NULL AND source_group_assignment_id IS NOT NULL)),
        CONSTRAINT ck_desired_states_version CHECK (version > 0),
        CONSTRAINT ck_desired_states_window CHECK (starts_at_utc IS NULL OR ends_at_utc IS NULL OR ends_at_utc > starts_at_utc),
        CONSTRAINT fk_desired_states_device_assignments_tenant FOREIGN KEY (tenant_id, source_device_assignment_id) REFERENCES app.device_assignments (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_desired_states_devices_tenant FOREIGN KEY (tenant_id, device_id) REFERENCES app.devices (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_desired_states_group_assignments_tenant FOREIGN KEY (tenant_id, source_group_assignment_id) REFERENCES app.group_assignments (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_desired_states_superseded_by_tenant FOREIGN KEY (tenant_id, superseded_by_desired_state_id) REFERENCES app.desired_states (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_desired_states_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE TABLE app.desired_state_assets (
        id uuid NOT NULL,
        desired_state_id uuid NOT NULL,
        content_version_id uuid NOT NULL,
        position integer NOT NULL,
        media_kind character varying(24) NOT NULL,
        byte_length bigint NOT NULL,
        sha256 bytea NOT NULL,
        duration_milliseconds integer,
        loop_video boolean NOT NULL,
        playback_json jsonb NOT NULL,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_desired_state_assets PRIMARY KEY (id),
        CONSTRAINT ak_desired_state_assets_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT ck_desired_state_assets_byte_length CHECK (byte_length >= 0),
        CONSTRAINT ck_desired_state_assets_duration CHECK (duration_milliseconds IS NULL OR duration_milliseconds > 0),
        CONSTRAINT ck_desired_state_assets_position CHECK (position >= 0),
        CONSTRAINT ck_desired_state_assets_sha256 CHECK (octet_length(sha256) = 32),
        CONSTRAINT fk_desired_state_assets_content_versions_tenant FOREIGN KEY (tenant_id, content_version_id) REFERENCES app.content_versions (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_desired_state_assets_states_tenant FOREIGN KEY (tenant_id, desired_state_id) REFERENCES app.desired_states (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_desired_state_assets_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE INDEX ix_content_assets_tenant_title ON app.content_assets (tenant_id, title);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE UNIQUE INDEX ux_content_versions_asset_version ON app.content_versions (tenant_id, content_asset_id, version_number);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE UNIQUE INDEX ux_content_versions_tenant_storage_key ON app.content_versions (tenant_id, storage_key);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE INDEX "IX_desired_state_assets_tenant_id_content_version_id" ON app.desired_state_assets (tenant_id, content_version_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE UNIQUE INDEX ux_desired_state_assets_state_position ON app.desired_state_assets (tenant_id, desired_state_id, position);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE INDEX "IX_desired_states_tenant_id_source_device_assignment_id" ON app.desired_states (tenant_id, source_device_assignment_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE INDEX "IX_desired_states_tenant_id_source_group_assignment_id" ON app.desired_states (tenant_id, source_group_assignment_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE INDEX "IX_desired_states_tenant_id_superseded_by_desired_state_id" ON app.desired_states (tenant_id, superseded_by_desired_state_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE UNIQUE INDEX ux_desired_states_device_version ON app.desired_states (tenant_id, device_id, version);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE INDEX ix_device_assignments_resolution ON app.device_assignments (tenant_id, device_id, is_enabled, priority);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE INDEX "IX_device_assignments_tenant_id_playlist_version_id" ON app.device_assignments (tenant_id, playlist_version_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE INDEX "IX_device_group_members_tenant_id_device_id" ON app.device_group_members (tenant_id, device_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE UNIQUE INDEX ux_device_group_members_group_device ON app.device_group_members (tenant_id, device_group_id, device_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE UNIQUE INDEX ux_device_groups_tenant_name ON app.device_groups (tenant_id, name);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE INDEX ix_group_assignments_resolution ON app.group_assignments (tenant_id, device_group_id, is_enabled, priority);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE INDEX "IX_group_assignments_tenant_id_playlist_version_id" ON app.group_assignments (tenant_id, playlist_version_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE INDEX ix_license_events_license_occurred ON app.license_events (tenant_id, license_id, occurred_at_utc);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE INDEX "IX_playlist_items_tenant_id_content_version_id" ON app.playlist_items (tenant_id, content_version_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE UNIQUE INDEX ux_playlist_items_version_position ON app.playlist_items (tenant_id, playlist_version_id, position);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE UNIQUE INDEX ux_playlist_versions_playlist_version ON app.playlist_versions (tenant_id, playlist_id, version_number);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE INDEX ix_playlists_tenant_name ON app.playlists (tenant_id, name);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    CREATE INDEX ix_system_keys_purpose_activation ON app.system_key_metadata (purpose, activates_at_utc);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    ALTER TABLE app.content_assets ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.content_assets FORCE ROW LEVEL SECURITY;
    CREATE POLICY content_assets_tenant_isolation ON app.content_assets
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.content_versions ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.content_versions FORCE ROW LEVEL SECURITY;
    CREATE POLICY content_versions_tenant_isolation ON app.content_versions
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.playlists ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.playlists FORCE ROW LEVEL SECURITY;
    CREATE POLICY playlists_tenant_isolation ON app.playlists
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.playlist_versions ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.playlist_versions FORCE ROW LEVEL SECURITY;
    CREATE POLICY playlist_versions_tenant_isolation ON app.playlist_versions
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.playlist_items ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.playlist_items FORCE ROW LEVEL SECURITY;
    CREATE POLICY playlist_items_tenant_isolation ON app.playlist_items
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.device_groups ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.device_groups FORCE ROW LEVEL SECURITY;
    CREATE POLICY device_groups_tenant_isolation ON app.device_groups
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.device_group_members ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.device_group_members FORCE ROW LEVEL SECURITY;
    CREATE POLICY device_group_members_tenant_isolation ON app.device_group_members
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.device_assignments ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.device_assignments FORCE ROW LEVEL SECURITY;
    CREATE POLICY device_assignments_tenant_isolation ON app.device_assignments
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.group_assignments ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.group_assignments FORCE ROW LEVEL SECURITY;
    CREATE POLICY group_assignments_tenant_isolation ON app.group_assignments
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.desired_states ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.desired_states FORCE ROW LEVEL SECURITY;
    CREATE POLICY desired_states_tenant_isolation ON app.desired_states
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.desired_state_assets ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.desired_state_assets FORCE ROW LEVEL SECURITY;
    CREATE POLICY desired_state_assets_tenant_isolation ON app.desired_state_assets
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.license_events ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.license_events FORCE ROW LEVEL SECURITY;
    CREATE POLICY license_events_tenant_isolation ON app.license_events
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815152308_ContentAndAssignmentCore') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260815152308_ContentAndAssignmentCore', '10.0.7');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815153239_DeviceIdentityAndTelemetry') THEN
    CREATE TABLE app.device_certificates (
        id uuid NOT NULL,
        device_id uuid NOT NULL,
        certificate_serial_number character varying(128) NOT NULL,
        thumbprint_sha256 bytea NOT NULL,
        subject_public_key_info_sha256 bytea NOT NULL,
        not_before_utc timestamp with time zone NOT NULL,
        not_after_utc timestamp with time zone NOT NULL,
        state character varying(24) NOT NULL,
        issued_at_utc timestamp with time zone NOT NULL,
        rotated_from_certificate_id uuid,
        revoked_at_utc timestamp with time zone,
        revocation_reason_code character varying(64),
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_device_certificates PRIMARY KEY (id),
        CONSTRAINT ak_device_certificates_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT ck_device_certificates_issuance CHECK (issued_at_utc >= not_before_utc AND issued_at_utc < not_after_utc),
        CONSTRAINT ck_device_certificates_revocation CHECK (state <> 'Revoked' OR (revoked_at_utc IS NOT NULL AND revocation_reason_code IS NOT NULL)),
        CONSTRAINT ck_device_certificates_spki CHECK (octet_length(subject_public_key_info_sha256) = 32),
        CONSTRAINT ck_device_certificates_thumbprint CHECK (octet_length(thumbprint_sha256) = 32),
        CONSTRAINT ck_device_certificates_validity CHECK (not_after_utc > not_before_utc),
        CONSTRAINT fk_device_certificates_devices_tenant FOREIGN KEY (tenant_id, device_id) REFERENCES app.devices (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_device_certificates_rotation_tenant FOREIGN KEY (tenant_id, rotated_from_certificate_id) REFERENCES app.device_certificates (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_device_certificates_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815153239_DeviceIdentityAndTelemetry') THEN
    CREATE TABLE app.device_heartbeats (
        id uuid NOT NULL,
        device_id uuid NOT NULL,
        sequence bigint NOT NULL,
        reported_sent_at_utc timestamp with time zone,
        received_at_utc timestamp with time zone NOT NULL,
        server_observed_ip character varying(64) NOT NULL,
        inventory_json jsonb NOT NULL,
        applied_desired_state_version bigint,
        player_state_code character varying(64) NOT NULL,
        free_disk_bytes bigint,
        last_error_code character varying(64),
        correlation_id uuid NOT NULL,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_device_heartbeats PRIMARY KEY (id),
        CONSTRAINT ak_device_heartbeats_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT ck_device_heartbeats_free_disk CHECK (free_disk_bytes IS NULL OR free_disk_bytes >= 0),
        CONSTRAINT ck_device_heartbeats_sequence CHECK (sequence > 0),
        CONSTRAINT fk_device_heartbeats_devices_tenant FOREIGN KEY (tenant_id, device_id) REFERENCES app.devices (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_device_heartbeats_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815153239_DeviceIdentityAndTelemetry') THEN
    CREATE TABLE app.device_network_interfaces (
        id uuid NOT NULL,
        device_id uuid NOT NULL,
        interface_name character varying(64) NOT NULL,
        mac_address_normalized character varying(12),
        local_addresses_json jsonb NOT NULL,
        observed_at_utc timestamp with time zone NOT NULL,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_device_network_interfaces PRIMARY KEY (id),
        CONSTRAINT ak_device_network_interfaces_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT fk_device_network_interfaces_devices_tenant FOREIGN KEY (tenant_id, device_id) REFERENCES app.devices (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_device_network_interfaces_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815153239_DeviceIdentityAndTelemetry') THEN
    CREATE TABLE app.device_synchronization_events (
        id uuid NOT NULL,
        device_id uuid NOT NULL,
        desired_state_version bigint,
        event_type character varying(64) NOT NULL,
        result_code character varying(64) NOT NULL,
        safe_details_json jsonb NOT NULL,
        reported_at_utc timestamp with time zone,
        received_at_utc timestamp with time zone NOT NULL,
        correlation_id uuid NOT NULL,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_device_synchronization_events PRIMARY KEY (id),
        CONSTRAINT ak_device_synchronization_events_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT ck_device_synchronization_events_version CHECK (desired_state_version IS NULL OR desired_state_version > 0),
        CONSTRAINT fk_device_synchronization_events_devices_tenant FOREIGN KEY (tenant_id, device_id) REFERENCES app.devices (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_device_synchronization_events_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815153239_DeviceIdentityAndTelemetry') THEN
    CREATE TABLE app.enrollment_tokens (
        id uuid NOT NULL,
        token_digest bytea NOT NULL,
        expected_device_id uuid,
        expected_serial_number_normalized character varying(64),
        expires_at_utc timestamp with time zone NOT NULL,
        consumed_at_utc timestamp with time zone,
        consumed_by_device_id uuid,
        revoked_at_utc timestamp with time zone,
        failed_attempt_count integer NOT NULL,
        last_failed_attempt_at_utc timestamp with time zone,
        created_by_user_id uuid NOT NULL,
        created_at_utc timestamp with time zone NOT NULL,
        concurrency_token uuid NOT NULL,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_enrollment_tokens PRIMARY KEY (id),
        CONSTRAINT ak_enrollment_tokens_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT ck_enrollment_tokens_consumption CHECK ((consumed_at_utc IS NULL) = (consumed_by_device_id IS NULL)),
        CONSTRAINT ck_enrollment_tokens_digest CHECK (octet_length(token_digest) = 32),
        CONSTRAINT ck_enrollment_tokens_expected_device CHECK (expected_device_id IS NULL OR consumed_by_device_id IS NULL OR expected_device_id = consumed_by_device_id),
        CONSTRAINT ck_enrollment_tokens_expiry CHECK (expires_at_utc > created_at_utc),
        CONSTRAINT ck_enrollment_tokens_failed_attempts CHECK (failed_attempt_count >= 0 AND failed_attempt_count <= 10),
        CONSTRAINT ck_enrollment_tokens_terminal_state CHECK (NOT (consumed_at_utc IS NOT NULL AND revoked_at_utc IS NOT NULL)),
        CONSTRAINT fk_enrollment_tokens_consuming_devices_tenant FOREIGN KEY (tenant_id, consumed_by_device_id) REFERENCES app.devices (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_enrollment_tokens_expected_devices_tenant FOREIGN KEY (tenant_id, expected_device_id) REFERENCES app.devices (tenant_id, id) ON DELETE RESTRICT,
        CONSTRAINT fk_enrollment_tokens_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815153239_DeviceIdentityAndTelemetry') THEN
    CREATE INDEX ix_device_certificates_device_state ON app.device_certificates (tenant_id, device_id, state);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815153239_DeviceIdentityAndTelemetry') THEN
    CREATE INDEX "IX_device_certificates_tenant_id_rotated_from_certificate_id" ON app.device_certificates (tenant_id, rotated_from_certificate_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815153239_DeviceIdentityAndTelemetry') THEN
    CREATE UNIQUE INDEX ux_device_certificates_serial ON app.device_certificates (certificate_serial_number);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815153239_DeviceIdentityAndTelemetry') THEN
    CREATE UNIQUE INDEX ux_device_certificates_thumbprint ON app.device_certificates (thumbprint_sha256);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815153239_DeviceIdentityAndTelemetry') THEN
    CREATE INDEX ix_device_heartbeats_device_received ON app.device_heartbeats (tenant_id, device_id, received_at_utc);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815153239_DeviceIdentityAndTelemetry') THEN
    CREATE UNIQUE INDEX ux_device_heartbeats_device_sequence ON app.device_heartbeats (tenant_id, device_id, sequence);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815153239_DeviceIdentityAndTelemetry') THEN
    CREATE UNIQUE INDEX ux_device_network_interfaces_device_name ON app.device_network_interfaces (tenant_id, device_id, interface_name);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815153239_DeviceIdentityAndTelemetry') THEN
    CREATE INDEX ix_device_synchronization_events_device_received ON app.device_synchronization_events (tenant_id, device_id, received_at_utc);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815153239_DeviceIdentityAndTelemetry') THEN
    CREATE INDEX ix_enrollment_tokens_tenant_expiry ON app.enrollment_tokens (tenant_id, expires_at_utc);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815153239_DeviceIdentityAndTelemetry') THEN
    CREATE INDEX "IX_enrollment_tokens_tenant_id_consumed_by_device_id" ON app.enrollment_tokens (tenant_id, consumed_by_device_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815153239_DeviceIdentityAndTelemetry') THEN
    CREATE INDEX "IX_enrollment_tokens_tenant_id_expected_device_id" ON app.enrollment_tokens (tenant_id, expected_device_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815153239_DeviceIdentityAndTelemetry') THEN
    CREATE UNIQUE INDEX ux_enrollment_tokens_digest ON app.enrollment_tokens (token_digest);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815153239_DeviceIdentityAndTelemetry') THEN
    ALTER TABLE app.device_certificates ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.device_certificates FORCE ROW LEVEL SECURITY;
    CREATE POLICY device_certificates_tenant_isolation ON app.device_certificates
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.device_heartbeats ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.device_heartbeats FORCE ROW LEVEL SECURITY;
    CREATE POLICY device_heartbeats_tenant_isolation ON app.device_heartbeats
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.device_network_interfaces ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.device_network_interfaces FORCE ROW LEVEL SECURITY;
    CREATE POLICY device_network_interfaces_tenant_isolation ON app.device_network_interfaces
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.device_synchronization_events ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.device_synchronization_events FORCE ROW LEVEL SECURITY;
    CREATE POLICY device_synchronization_events_tenant_isolation ON app.device_synchronization_events
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.enrollment_tokens ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.enrollment_tokens FORCE ROW LEVEL SECURITY;
    CREATE POLICY enrollment_tokens_tenant_isolation ON app.enrollment_tokens
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815153239_DeviceIdentityAndTelemetry') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260815153239_DeviceIdentityAndTelemetry', '10.0.7');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE TABLE app.identity_roles (
        id uuid NOT NULL,
        name character varying(256),
        normalized_name character varying(256),
        concurrency_stamp text,
        CONSTRAINT "PK_identity_roles" PRIMARY KEY (id)
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE TABLE app.identity_users (
        id uuid NOT NULL,
        display_name character varying(160) NOT NULL,
        account_state character varying(24) NOT NULL,
        created_at_utc timestamp with time zone NOT NULL,
        updated_at_utc timestamp with time zone NOT NULL,
        last_password_changed_at_utc timestamp with time zone,
        user_name character varying(256),
        normalized_user_name character varying(256),
        email character varying(320),
        normalized_email character varying(320),
        email_confirmed boolean NOT NULL,
        password_hash text,
        security_stamp text,
        concurrency_stamp text,
        phone_number character varying(32),
        phone_number_confirmed boolean NOT NULL,
        two_factor_enabled boolean NOT NULL,
        lockout_end_utc timestamp with time zone,
        lockout_enabled boolean NOT NULL,
        access_failed_count integer NOT NULL,
        CONSTRAINT "PK_identity_users" PRIMARY KEY (id)
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE TABLE app.identity_role_claims (
        id integer GENERATED BY DEFAULT AS IDENTITY,
        role_id uuid NOT NULL,
        claim_type text,
        claim_value text,
        CONSTRAINT "PK_identity_role_claims" PRIMARY KEY (id),
        CONSTRAINT "FK_identity_role_claims_identity_roles_role_id" FOREIGN KEY (role_id) REFERENCES app.identity_roles (id) ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE TABLE app.identity_user_claims (
        id integer GENERATED BY DEFAULT AS IDENTITY,
        user_id uuid NOT NULL,
        claim_type text,
        claim_value text,
        CONSTRAINT "PK_identity_user_claims" PRIMARY KEY (id),
        CONSTRAINT "FK_identity_user_claims_identity_users_user_id" FOREIGN KEY (user_id) REFERENCES app.identity_users (id) ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE TABLE app.identity_user_logins (
        login_provider character varying(128) NOT NULL,
        provider_key character varying(256) NOT NULL,
        provider_display_name text,
        user_id uuid NOT NULL,
        CONSTRAINT "PK_identity_user_logins" PRIMARY KEY (login_provider, provider_key),
        CONSTRAINT "FK_identity_user_logins_identity_users_user_id" FOREIGN KEY (user_id) REFERENCES app.identity_users (id) ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE TABLE app.identity_user_roles (
        user_id uuid NOT NULL,
        role_id uuid NOT NULL,
        CONSTRAINT "PK_identity_user_roles" PRIMARY KEY (user_id, role_id),
        CONSTRAINT "FK_identity_user_roles_identity_roles_role_id" FOREIGN KEY (role_id) REFERENCES app.identity_roles (id) ON DELETE CASCADE,
        CONSTRAINT "FK_identity_user_roles_identity_users_user_id" FOREIGN KEY (user_id) REFERENCES app.identity_users (id) ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE TABLE app.identity_user_tokens (
        user_id uuid NOT NULL,
        login_provider character varying(128) NOT NULL,
        name character varying(128) NOT NULL,
        value text,
        CONSTRAINT "PK_identity_user_tokens" PRIMARY KEY (user_id, login_provider, name),
        CONSTRAINT "FK_identity_user_tokens_identity_users_user_id" FOREIGN KEY (user_id) REFERENCES app.identity_users (id) ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE TABLE app.invitations (
        id uuid NOT NULL,
        normalized_email character varying(320) NOT NULL,
        intended_role character varying(32) NOT NULL,
        token_digest bytea NOT NULL,
        expires_at_utc timestamp with time zone NOT NULL,
        consumed_at_utc timestamp with time zone,
        consumed_by_user_id uuid,
        revoked_at_utc timestamp with time zone,
        created_by_user_id uuid NOT NULL,
        created_at_utc timestamp with time zone NOT NULL,
        concurrency_token uuid NOT NULL,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_invitations PRIMARY KEY (id),
        CONSTRAINT ak_invitations_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT ck_invitations_consumption CHECK ((consumed_at_utc IS NULL) = (consumed_by_user_id IS NULL)),
        CONSTRAINT ck_invitations_digest CHECK (octet_length(token_digest) = 32),
        CONSTRAINT ck_invitations_expiry CHECK (expires_at_utc > created_at_utc),
        CONSTRAINT ck_invitations_terminal_state CHECK (NOT (consumed_at_utc IS NOT NULL AND revoked_at_utc IS NOT NULL)),
        CONSTRAINT fk_invitations_consuming_users FOREIGN KEY (consumed_by_user_id) REFERENCES app.identity_users (id) ON DELETE RESTRICT,
        CONSTRAINT fk_invitations_creators FOREIGN KEY (created_by_user_id) REFERENCES app.identity_users (id) ON DELETE RESTRICT,
        CONSTRAINT fk_invitations_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE TABLE app.tenant_memberships (
        id uuid NOT NULL,
        user_id uuid NOT NULL,
        role character varying(32) NOT NULL,
        state character varying(24) NOT NULL,
        invited_by_user_id uuid NOT NULL,
        accepted_at_utc timestamp with time zone NOT NULL,
        created_at_utc timestamp with time zone NOT NULL,
        updated_at_utc timestamp with time zone NOT NULL,
        concurrency_token uuid NOT NULL,
        tenant_id uuid NOT NULL,
        CONSTRAINT pk_tenant_memberships PRIMARY KEY (id),
        CONSTRAINT ak_tenant_memberships_tenant_id_id UNIQUE (tenant_id, id),
        CONSTRAINT fk_tenant_memberships_inviters FOREIGN KEY (invited_by_user_id) REFERENCES app.identity_users (id) ON DELETE RESTRICT,
        CONSTRAINT fk_tenant_memberships_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT,
        CONSTRAINT fk_tenant_memberships_users FOREIGN KEY (user_id) REFERENCES app.identity_users (id) ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE TABLE app.user_mfa_secrets (
        user_id uuid NOT NULL,
        protected_secret bytea NOT NULL,
        protection_scheme character varying(128) NOT NULL,
        created_at_utc timestamp with time zone NOT NULL,
        confirmed_at_utc timestamp with time zone,
        updated_at_utc timestamp with time zone NOT NULL,
        concurrency_token uuid NOT NULL,
        CONSTRAINT pk_user_mfa_secrets PRIMARY KEY (user_id),
        CONSTRAINT ck_user_mfa_secrets_payload CHECK (octet_length(protected_secret) > 0),
        CONSTRAINT fk_user_mfa_secrets_users FOREIGN KEY (user_id) REFERENCES app.identity_users (id) ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE TABLE app.user_recovery_codes (
        id uuid NOT NULL,
        user_id uuid NOT NULL,
        code_digest bytea NOT NULL,
        created_at_utc timestamp with time zone NOT NULL,
        used_at_utc timestamp with time zone,
        CONSTRAINT pk_user_recovery_codes PRIMARY KEY (id),
        CONSTRAINT ck_user_recovery_codes_digest CHECK (octet_length(code_digest) = 32),
        CONSTRAINT fk_user_recovery_codes_users FOREIGN KEY (user_id) REFERENCES app.identity_users (id) ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE TABLE app.user_sessions (
        id uuid NOT NULL,
        user_id uuid NOT NULL,
        session_key_digest bytea NOT NULL,
        selected_tenant_id uuid,
        security_stamp_digest bytea NOT NULL,
        mfa_satisfied boolean NOT NULL,
        mfa_satisfied_at_utc timestamp with time zone,
        created_at_utc timestamp with time zone NOT NULL,
        last_seen_at_utc timestamp with time zone NOT NULL,
        idle_expires_at_utc timestamp with time zone NOT NULL,
        absolute_expires_at_utc timestamp with time zone NOT NULL,
        revoked_at_utc timestamp with time zone,
        revocation_reason_code character varying(64),
        user_agent_digest bytea,
        source_address_digest bytea,
        concurrency_token uuid NOT NULL,
        CONSTRAINT pk_user_sessions PRIMARY KEY (id),
        CONSTRAINT ck_user_sessions_expiry CHECK (idle_expires_at_utc > created_at_utc AND absolute_expires_at_utc >= idle_expires_at_utc),
        CONSTRAINT ck_user_sessions_key_digest CHECK (octet_length(session_key_digest) = 32),
        CONSTRAINT ck_user_sessions_mfa CHECK ((mfa_satisfied = FALSE AND mfa_satisfied_at_utc IS NULL) OR (mfa_satisfied = TRUE AND mfa_satisfied_at_utc IS NOT NULL)),
        CONSTRAINT ck_user_sessions_source_address_digest CHECK (source_address_digest IS NULL OR octet_length(source_address_digest) = 32),
        CONSTRAINT ck_user_sessions_stamp_digest CHECK (octet_length(security_stamp_digest) = 32),
        CONSTRAINT ck_user_sessions_user_agent_digest CHECK (user_agent_digest IS NULL OR octet_length(user_agent_digest) = 32),
        CONSTRAINT fk_user_sessions_selected_tenants FOREIGN KEY (selected_tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT,
        CONSTRAINT fk_user_sessions_users FOREIGN KEY (user_id) REFERENCES app.identity_users (id) ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE INDEX "IX_identity_role_claims_role_id" ON app.identity_role_claims (role_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE UNIQUE INDEX ux_identity_roles_normalized_name ON app.identity_roles (normalized_name);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE INDEX "IX_identity_user_claims_user_id" ON app.identity_user_claims (user_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE INDEX "IX_identity_user_logins_user_id" ON app.identity_user_logins (user_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE INDEX "IX_identity_user_roles_role_id" ON app.identity_user_roles (role_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE INDEX ix_identity_users_normalized_email ON app.identity_users (normalized_email);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE UNIQUE INDEX ux_identity_users_normalized_user_name ON app.identity_users (normalized_user_name);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE INDEX "IX_invitations_consumed_by_user_id" ON app.invitations (consumed_by_user_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE INDEX "IX_invitations_created_by_user_id" ON app.invitations (created_by_user_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE UNIQUE INDEX ux_invitations_digest ON app.invitations (token_digest);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE UNIQUE INDEX ux_invitations_tenant_pending_email ON app.invitations (tenant_id, normalized_email) WHERE consumed_at_utc IS NULL AND revoked_at_utc IS NULL;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE INDEX "IX_tenant_memberships_invited_by_user_id" ON app.tenant_memberships (invited_by_user_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE UNIQUE INDEX ux_tenant_memberships_single_current_tenant ON app.tenant_memberships (user_id) WHERE state <> 'Removed';
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE UNIQUE INDEX ux_tenant_memberships_tenant_user ON app.tenant_memberships (tenant_id, user_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE UNIQUE INDEX ux_user_recovery_codes_user_digest ON app.user_recovery_codes (user_id, code_digest);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE INDEX "IX_user_sessions_selected_tenant_id" ON app.user_sessions (selected_tenant_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE INDEX ix_user_sessions_user_active ON app.user_sessions (user_id, revoked_at_utc, absolute_expires_at_utc);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    CREATE UNIQUE INDEX ux_user_sessions_key_digest ON app.user_sessions (session_key_digest);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    ALTER TABLE app.invitations ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.invitations FORCE ROW LEVEL SECURITY;
    CREATE POLICY invitations_tenant_isolation ON app.invitations
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

    ALTER TABLE app.tenant_memberships ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.tenant_memberships FORCE ROW LEVEL SECURITY;
    CREATE POLICY tenant_memberships_tenant_isolation ON app.tenant_memberships
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815154500_HumanIdentityCore') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260815154500_HumanIdentityCore', '10.0.7');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815155124_MfaReplayGuard') THEN
    ALTER TABLE app.user_mfa_secrets ADD last_accepted_time_step bigint;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815155124_MfaReplayGuard') THEN
    ALTER TABLE app.user_mfa_secrets ADD CONSTRAINT ck_user_mfa_secrets_last_step CHECK (last_accepted_time_step IS NULL OR last_accepted_time_step >= 0);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815155124_MfaReplayGuard') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260815155124_MfaReplayGuard', '10.0.7');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815155557_IdentityTenantLocator') THEN
    DROP INDEX app.ix_identity_users_normalized_email;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815155557_IdentityTenantLocator') THEN
    ALTER TABLE app.identity_users ADD home_tenant_id uuid;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815155557_IdentityTenantLocator') THEN
    CREATE INDEX ix_identity_users_home_tenant ON app.identity_users (home_tenant_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815155557_IdentityTenantLocator') THEN
    CREATE UNIQUE INDEX ux_identity_users_normalized_email ON app.identity_users (normalized_email);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815155557_IdentityTenantLocator') THEN
    ALTER TABLE app.identity_users ADD CONSTRAINT fk_identity_users_home_tenants FOREIGN KEY (home_tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815155557_IdentityTenantLocator') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260815155557_IdentityTenantLocator', '10.0.7');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815161916_RecoveryCodeReplayGuard') THEN
    ALTER TABLE app.user_recovery_codes ADD concurrency_token uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000';
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815161916_RecoveryCodeReplayGuard') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260815161916_RecoveryCodeReplayGuard', '10.0.7');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815162523_IdentityNotificationOutbox') THEN
    CREATE TABLE app.identity_notifications (
        id uuid NOT NULL,
        user_id uuid NOT NULL,
        tenant_id uuid,
        notification_type character varying(64) NOT NULL,
        normalized_recipient_email character varying(320) NOT NULL,
        protected_payload bytea NOT NULL,
        created_at_utc timestamp with time zone NOT NULL,
        next_attempt_at_utc timestamp with time zone NOT NULL,
        processed_at_utc timestamp with time zone,
        attempt_count integer NOT NULL,
        last_safe_error_code character varying(64),
        concurrency_token uuid NOT NULL,
        CONSTRAINT pk_identity_notifications PRIMARY KEY (id),
        CONSTRAINT ck_identity_notifications_attempts CHECK (attempt_count >= 0),
        CONSTRAINT ck_identity_notifications_payload CHECK (octet_length(protected_payload) > 0 AND octet_length(protected_payload) <= 16384),
        CONSTRAINT fk_identity_notifications_tenants FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE RESTRICT,
        CONSTRAINT fk_identity_notifications_users FOREIGN KEY (user_id) REFERENCES app.identity_users (id) ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815162523_IdentityNotificationOutbox') THEN
    CREATE INDEX ix_identity_notifications_pending ON app.identity_notifications (processed_at_utc, next_attempt_at_utc);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815162523_IdentityNotificationOutbox') THEN
    CREATE INDEX "IX_identity_notifications_tenant_id" ON app.identity_notifications (tenant_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815162523_IdentityNotificationOutbox') THEN
    CREATE INDEX "IX_identity_notifications_user_id" ON app.identity_notifications (user_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815162523_IdentityNotificationOutbox') THEN
    ALTER TABLE app.identity_notifications ENABLE ROW LEVEL SECURITY;
    ALTER TABLE app.identity_notifications FORCE ROW LEVEL SECURITY;
    CREATE POLICY identity_notifications_tenant_isolation ON app.identity_notifications
        FOR INSERT
        WITH CHECK (
            tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid
            OR (
                tenant_id IS NULL
                AND NULLIF(current_setting('app.tenant_id', true), '') IS NULL
            )
        );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815162523_IdentityNotificationOutbox') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260815162523_IdentityNotificationOutbox', '10.0.7');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815162617_IdentityNotificationProtectionScheme') THEN
    ALTER TABLE app.identity_notifications ADD protection_scheme character varying(128) NOT NULL DEFAULT '';
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815162617_IdentityNotificationProtectionScheme') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260815162617_IdentityNotificationProtectionScheme', '10.0.7');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815185953_StoreIssuedDeviceCertificateDer') THEN
    ALTER TABLE app.device_certificates ADD certificate_der bytea;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815185953_StoreIssuedDeviceCertificateDer') THEN
    ALTER TABLE app.device_certificates ADD CONSTRAINT ck_device_certificates_der CHECK (certificate_der IS NULL OR (octet_length(certificate_der) >= 100 AND octet_length(certificate_der) <= 16384));
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815185953_StoreIssuedDeviceCertificateDer') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260815185953_StoreIssuedDeviceCertificateDer', '10.0.7');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815204500_PlatformTenantCatalogPolicy') THEN
    CREATE POLICY tenants_platform_catalog_select ON app.tenants
        FOR SELECT
        USING (current_setting('app.platform_catalog', true) = 'true');
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815204500_PlatformTenantCatalogPolicy') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260815204500_PlatformTenantCatalogPolicy', '10.0.7');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815204600_SeedPlatformAdministratorRole') THEN
    INSERT INTO app.identity_roles (id, name, normalized_name, concurrency_stamp)
    VALUES ('f0000000-0000-0000-0000-000000000001', 'PlatformAdministrator', 'PLATFORMADMINISTRATOR', 'migration-seed-v1')
    ON CONFLICT DO NOTHING;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815204600_SeedPlatformAdministratorRole') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260815204600_SeedPlatformAdministratorRole', '10.0.7');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815204700_NotificationDeliveryPolicy') THEN
    CREATE POLICY identity_notifications_delivery_select ON app.identity_notifications
        FOR SELECT
        USING (current_setting('app.notification_delivery', true) = 'true');

    CREATE POLICY identity_notifications_delivery_update ON app.identity_notifications
        FOR UPDATE
        USING (current_setting('app.notification_delivery', true) = 'true')
        WITH CHECK (current_setting('app.notification_delivery', true) = 'true');
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815204700_NotificationDeliveryPolicy') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260815204700_NotificationDeliveryPolicy', '10.0.7');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815204800_AllowUserlessInvitationNotifications') THEN
    ALTER TABLE app.identity_notifications ALTER COLUMN user_id TYPE uuid;
    ALTER TABLE app.identity_notifications ALTER COLUMN user_id DROP NOT NULL;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815204800_AllowUserlessInvitationNotifications') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260815204800_AllowUserlessInvitationNotifications', '10.0.7');
    END IF;
END $EF$;
COMMIT;
