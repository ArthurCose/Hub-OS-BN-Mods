// should be called from the root folder:
// node utils/update-packs.js

// assumes package ids match folder name

const fs = require("fs");
const path = require("path");

const cardsFolder = "mods/cards";
const augmentsFolder = "mods/augments";
const librariesFolder = "mods/libraries";

/**
 * @param {string} categoryFolder
 * @param {(id: string) => boolean} filter
 * @returns { { [namespace: string]: string[] } }
 */
function packagesByNamespace(categoryFolder, filter) {
  /** @type { [namespace: string]: string[] } */
  const idMap = {};

  for (let id of fs.readdirSync(categoryFolder)) {
    id = decodeURIComponent(id);

    if (!id.startsWith("BattleNetwork") || !filter(id)) {
      continue;
    }

    const dotIndex = id.indexOf(".");

    if (dotIndex < 0) {
      continue;
    }

    const namespace = id.slice(0, dotIndex);

    /** @type {string[] | undefined} */
    let list = idMap[namespace];

    if (!list) {
      list = [];
      idMap[namespace] = list;
    }

    list.push(id);
  }

  return idMap;
}

/**
 * @param {string} id
 * @param {string} name
 * @param {string} description
 * @param { { [category: string]: string[] } } dependencies
 */
function savePack(id, name, description, dependencies) {
  let content = `\
[package]
category = "pack"
id = "${id}"
name = "${name}"
description = "${description}"

[dependencies]
`;

  for (const category in dependencies) {
    const ids = dependencies[category];
    ids.sort();

    content += category + " = [\n";
    content += ids.map((id) => `  "${id}",\n`).join("");
    content += "]\n";
  }

  const folderPath = path.join(librariesFolder, id);

  try {
    fs.mkdirSync(folderPath);
  } catch {}

  fs.writeFileSync(path.join(folderPath, "package.toml"), content);
}

// NCP
const ncpNamespaceMap = packagesByNamespace(
  augmentsFolder,
  (id) =>
    id["BattleNetwork".length + 1] == "." && // must come from a BattleNetwork[number] namepace
    id.includes(".Program") // must be an NCP, no bugs or mod cards
);

for (const namespace in ncpNamespaceMap) {
  savePack(
    `${namespace}.Packs.NCPs`,
    `BN${namespace.slice(-1)} NCPs`,
    `Every NCP in the ${namespace} namespace`,
    { augments: ncpNamespaceMap[namespace] }
  );
}

savePack(
  "BattleNetwork.Packs.NCPs",
  "BN NCPs",
  "Every NCP in the BattleNetwork namespaces",
  { libraries: Object.keys(ncpNamespaceMap).map((ns) => `${ns}.Packs.NCPs`) }
);

// Chips
const chipNamespaceMap = packagesByNamespace(
  cardsFolder,
  (id) =>
    id["BattleNetwork".length + 1] == "." && // must come from a BattleNetwork[number] namepace
    !id.includes(".EX.") && // must be fully vanilla
    !id.includes("Alternative") && // must be fully vanilla
    (id.includes(".Class") || id.includes(".ProgramAdvance")) // exclude helper chips (RecoveryBase)
);

for (const namespace in chipNamespaceMap) {
  savePack(
    `${namespace}.Packs.Chips`,
    `BN${namespace.slice(-1)} Chips`,
    `Every chip in the ${namespace} namespace`,
    { cards: chipNamespaceMap[namespace] }
  );
}

savePack(
  "BattleNetwork.Packs.Chips",
  "BN Chips",
  "Every chip in the BattleNetwork namespaces",
  { cards: Object.keys(chipNamespaceMap).map((ns) => `${ns}.Packs.Chips`) }
);
