# M6-Installationsprofile

English: [English version](installation-profiles.md)

Installationsprofile sind kontrollierte TSV-Eingaben und keine zweite Rechnerdatenbank. Das bestehende SASD-Inventar bleibt für Rechnerrolle und Monitoring-Profil maßgeblich; M6-Hostzeilen ergänzen nur Bootidentität und Netzwerkinstallationsdaten.

Das Feld `method` ist eines von `image`, `jumpstart`, `kickstart` oder `fai`. Das Profil nennt Image-Datensatz, Architektur, Installationsquelle, Rolle, Partitionsbeschreibung, Postinstallationspfad und SASD-Monitoring-Profil. Es enthält kein Kennwort, keinen privaten Schlüssel, keine Enrollment-Freigabe und kein Secret.

Die SHA256 des Images ist eine Auswahlprüfung. Vor einer späteren Installation müssen zusätzlich Quelle, Zielkapazität, Bootanforderungen und Postinstallationsplan geprüft werden. Ein Profil kann kein M2-Enrollment genehmigen und keinen Schreibzugriff auf eine Systemplatte freigeben.

Die Vorlagen unter `site/install/adapters/` sind versionsbezogene Kandidaten. Ihre Existenz ist keine native Abnahme. Vor einer Kompatibilitätsaussage sind genaues OS, Installer, Quell-Checksumme, Kommandoausgabe und Cleanup-Nachweis erforderlich.
