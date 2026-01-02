const fs = require("fs");
const path = require("path");
const toml = require("toml");

const modsFolder = "../../mods";

for (const categoryFolder of fs.readdirSync(modsFolder)) {
  const categoryPath = path.join(modsFolder, categoryFolder);

  for (const modFolder of fs.readdirSync(categoryPath)) {
    if (modFolder.startsWith("_")) {
      continue;
    }

    const modPath = path.join(categoryPath, modFolder);

    try {
      const contents = fs.readFileSync(
        path.join(modPath, "package.toml"),
        "utf8"
      );
      const packageMeta = toml.parse(contents);
      const packageId = packageMeta.package.id;

      if (modFolder == packageId) {
        continue;
      }

      fs.renameSync(
        modPath,
        path.join(categoryPath, encodeURIComponent(packageId))
      );
    } catch (err) {
      console.error(`Failed to read package.toml in ${modPath}: \n`, err);
    }
  }
}
