CREATE TABLE IF NOT EXISTS hormones_metadata (
	name VARCHAR(20) PRIMARY KEY,
	val  VARCHAR(20)
);
INSERT INTO hormones_metadata (name, val) VALUES ('version', $version);

CREATE TABLE IF NOT EXISTS hormones_organs (
	organId TINYINT UNSIGNED PRIMARY KEY,
	name    VARCHAR(64) UNIQUE
)
	AUTO_INCREMENT = 0;
DELIMITER $$
CREATE TRIGGER organs_organId_limit
BEFORE INSERT ON hormones_organs
FOR EACH ROW
	BEGIN
		IF (NEW.organId < 0 OR NEW.organId > 63)
		THEN
			SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = 'organ flag';
		END IF;
	END $$
CREATE FUNCTION organ_name_to_id(inName VARCHAR(64))
	RETURNS TINYINT
DETERMINISTIC
	BEGIN
		DECLARE id TINYINT UNSIGNED;
		DECLARE empty_id TINYINT UNSIGNED;

		SELECT organId
		INTO @id
		FROM hormones_organs
		WHERE hormones_organs.name = inName;
		IF ROW_COUNT() = 1
		THEN
			-- just select, no need to change stuff
			RETURN @id;
		ELSE
			IF (SELECT COUNT(*)
			    FROM hormones_organs) = 64
			THEN
				-- table full, try to empty some rows
				DELETE FROM hormones_organs
				WHERE NOT EXISTS(SELECT tissueId
				                 FROM hormones_tissues
				                 WHERE hormones_tissues.organId = hormones_organs.organId);
				IF ROW_COUNT() = 0
				THEN
					SIGNAL SQLSTATE '45000'
					SET MESSAGE_TEXT = 'Too many organs; consider deleting unused ones';
				END IF;
			END IF;
			-- find the first empty row
			IF NOT EXISTS(SELECT name
			              FROM hormones_organs
			              WHERE hormones_organs.organId = 0)
			THEN
				-- our gap-finding query doesn't work if 0 i
				INSERT INTO hormones_organs (organId, name) VALUES (0, inName);
				RETURN 0;
			ELSE
				-- detect gaps
				SELECT (hormones_organs.organId + 1)
				INTO @empty_id
				FROM hormones_organs
					LEFT JOIN hormones_organs organs_2 ON organs_2.organId = hormones_organs.organId + 1
				WHERE organs_2.organId IS NULL
				ORDER BY hormones_organs.organId ASC
				LIMIT 1;
				IF ROW_COUNT() = 1
				THEN
					INSERT INTO hormones_organs (organId, name) VALUES (@empty_id, inName);
					RETURN @empty_id;
				ELSE
					SIGNAL SQLSTATE '45000'
					SET MESSAGE_TEXT = 'Assertion error: organ count is not 64, but no gaps found and organId=0 is not null';
				END IF;
			END IF;
		END IF;
	END $$
DELIMITER ;

CREATE TABLE hormones_blood (
	hormoneId BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	type      VARCHAR(64) NOT NULL,
	receptors BIT(64)                     DEFAULT x'FFFFFFFFFFFFFFFF',
	creation  TIMESTAMP   NOT NULL        DEFAULT CURRENT_TIMESTAMP,
	expiry    TIMESTAMP   NOT NULL        DEFAULT CURRENT_TIMESTAMP,
	json      TEXT
);
-- type: the hormone type, in the format "namespace.hormoneName", e.g. "hormones.moderation.Mute"

CREATE TABLE hormones_tissues (
	tissueId        CHAR(32) PRIMARY KEY,
	organId         TINYINT UNSIGNED NOT NULL,
	lastOnline      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	usedSlots       SMALLINT UNSIGNED,
	maxSlots        SMALLINT UNSIGNED,
	ip              VARCHAR(68),
	port            SMALLINT UNSIGNED,
	hormonesVersion MEDIUMINT,
	displayName     VARCHAR(100),
	processId       SMALLINT UNSIGNED,
	FOREIGN KEY (organId) REFERENCES hormones_organs (organId)
		ON UPDATE RESTRICT
		ON DELETE CASCADE
);
-- tissueId is a unique ID generated by Hormones, different from Server::getServerUniqueId()

CREATE TABLE hormones_accstate (
	username   VARCHAR(20) PRIMARY KEY,
	lastOrgan  TINYINT UNSIGNED DEFAULT NULL,
	lastTissue CHAR(32)         DEFAULT NULL,
	lastOnline TIMESTAMP        DEFAULT CURRENT_TIMESTAMP,
	FOREIGN KEY (lastOrgan) REFERENCES hormones_organs (organId)
		ON UPDATE CASCADE
		ON DELETE SET NULL,
	FOREIGN KEY (lastTissue) REFERENCES hormones_tissues (tissueId)
		ON UPDATE CASCADE
		ON DELETE SET NULL
);
>>>>>>> more-transfer
