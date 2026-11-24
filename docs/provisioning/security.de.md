# M5-Sicherheitsgrenzen

English: [English version](security.md)

- Als unprivilegierter Benutzer in einem Wegwerfverzeichnis ausführen.
- Quelle und Repository ausdrücklich auswählen; unsichere Pfadbestandteile und Symlink-Vorfahren ablehnen.
- Die Werkzeuge nicht auf `/`, einen aktiven Produktivbaum, ein gemountetes Produktivdateisystem oder ein Blockgerät richten.
- Keine privaten Schlüssel, Enrollment-Secrets, Kennwörter oder Produktionsinventare in ein Image-Repository legen.
- Ein Golden-Archiv erst nach Prüfung von Manifest und Prüfsumme als vertrauenswürdig behandeln.
- Nur in ein neues Verzeichnis wiederherstellen. Vorhandene Ziele, Archiv-Links, Spezialdateien, absolute Namen und Traversal werden abgelehnt.
- Das Archiv ist keine Quelle der Rechneridentität. SSH- und Monitoring-Identitäten müssen separat hostindividuell erzeugt oder bereitgestellt werden.
- Ein Live-Capture ist nicht automatisch konsistent. Vor Verwendung den Quellbaum anhalten oder einen Dateisystem-Snapshot benutzen.

Die Werkzeuge konfigurieren keinen Bootloader, partitionieren keine Platte, mounten kein Dateisystem, starten keinen Netzwerkdienst und führen keine Postinstallationsskripte aus. Diese Vorgänge benötigen eigene M6-/M7-Entwürfe und Abnahmen.
