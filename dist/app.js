const { invoke } = window.__TAURI__.core;

const state = {
  root: null,
  outputPath: null,
  previewContent: null,
};

const el = (id) => document.getElementById(id);

function showView(id) {
  document.querySelectorAll(".view").forEach((v) => v.classList.remove("active"));
  el(id).classList.add("active");
}

function renderRootSummary() {
  el("root-summary").textContent = state.root || "No folder selected";
  updateGenerateEnabled();
}

function renderOutputSummary() {
  el("output-summary").textContent = state.outputPath || "No save location selected";
  updateGenerateEnabled();
}

function updateGenerateEnabled() {
  const previewMode = el("preview-mode").checked;
  el("generate-btn").disabled = !state.root || (!previewMode && !state.outputPath);
}

function updateOutputFieldAvailability() {
  const previewMode = el("preview-mode").checked;
  el("pick-output").disabled = previewMode;
  el("output-field").classList.toggle("disabled-field", previewMode);
  updateGenerateEnabled();
}

async function openSetup(isFirstRun) {
  const s = await invoke("get_settings");
  el("setup-title").textContent = isFirstRun ? "Welcome to GODLister" : "Listing Settings";
  el("setup-intro").textContent = isFirstRun
    ? "Let's set your default options. You can change these again later from the settings button."
    : "Update your default options below.";
  el("setup-cancel").hidden = isFirstRun;

  el("depth-count").value = s.default_depth;
  el("depth-count").min = -1;

  el("god-recognition").checked = s.god_recognition;
  el("content-type-recognition").checked = s.content_type_recognition;
  updateContentTypeAvailability();

  el("freq-every-time").checked = s.ask_every_time;
  el("freq-once").checked = !s.ask_every_time;

  showView("setup-view");
}

function updateContentTypeAvailability() {
  const godOn = el("god-recognition").checked;
  const contentTypeCheckbox = el("content-type-recognition");
  contentTypeCheckbox.disabled = !godOn;
  if (!godOn) {
    contentTypeCheckbox.checked = false;
  }
}

async function saveSetup() {
  const defaultDepth = Math.max(-1, parseInt(el("depth-count").value, 10) || 0);
  const godRecognition = el("god-recognition").checked;
  const contentTypeRecognition = el("content-type-recognition").checked;
  const askEveryTime = el("freq-every-time").checked;

  await invoke("save_settings", {
    askEveryTime,
    defaultDepth,
    godRecognition,
    contentTypeRecognition,
  });

  showView("main-view");
}

async function init() {
  const s = await invoke("get_settings");

  if (!s.configured || s.ask_every_time) {
    await openSetup(!s.configured);
  } else {
    showView("main-view");
  }

  updateOutputFieldAvailability();

  el("setup-save").addEventListener("click", saveSetup);
  el("setup-cancel").addEventListener("click", () => showView("main-view"));
  el("open-settings").addEventListener("click", () => openSetup(false));
  el("god-recognition").addEventListener("change", updateContentTypeAvailability);

  el("pick-root").addEventListener("click", async () => {
    const picked = await invoke("pick_scan_root");
    if (picked) {
      state.root = picked;
      renderRootSummary();
    }
  });

  el("pick-output").addEventListener("click", async () => {
    const picked = await invoke("pick_output_path");
    if (picked) {
      state.outputPath = picked;
      renderOutputSummary();
    }
  });

  el("preview-mode").addEventListener("change", updateOutputFieldAvailability);

  el("generate-btn").addEventListener("click", runGenerate);

  el("preview-close").addEventListener("click", closePreview);
  el("preview-save").addEventListener("click", saveFromPreview);
}

function closePreview() {
  el("preview-overlay").hidden = true;
  el("preview-text").textContent = "";
  state.previewContent = null;
}

async function saveFromPreview() {
  if (state.previewContent === null) return;
  const picked = await invoke("pick_output_path");
  if (!picked) return;
  try {
    await invoke("save_text", { path: picked, text: state.previewContent });
    closePreview();
    const resultArea = el("result-area");
    resultArea.hidden = false;
    resultArea.className = "success";
    resultArea.textContent = `Saved to ${picked}`;
  } catch (err) {
    el("preview-counts").textContent = `Error saving: ${err}`;
  }
}

async function runGenerate() {
  const previewMode = el("preview-mode").checked;

  el("generate-btn").disabled = true;
  el("pick-root").disabled = true;
  el("pick-output").disabled = true;
  el("result-area").hidden = true;

  const resultArea = el("result-area");
  try {
    const summary = await invoke("generate_listing", {
      root: state.root,
      outputPath: previewMode ? null : state.outputPath,
    });

    if (summary.content !== null && summary.content !== undefined) {
      state.previewContent = summary.content;
      el("preview-counts").textContent =
        `${summary.entries_written} entr${summary.entries_written === 1 ? "y" : "ies"}` +
        (summary.god_matches > 0 ? ` · ${summary.god_matches} GOD title${summary.god_matches === 1 ? "" : "s"}` : "") +
        (summary.content_type_matches > 0 ? ` · ${summary.content_type_matches} content-type match${summary.content_type_matches === 1 ? "" : "es"}` : "") +
        (summary.dlc_matches > 0 ? ` · ${summary.dlc_matches} DLC name${summary.dlc_matches === 1 ? "" : "s"}` : "");
      el("preview-text").textContent = summary.content;
      el("preview-overlay").hidden = false;
    } else {
      resultArea.hidden = false;
      resultArea.className = "success";
      resultArea.textContent =
        `Wrote ${summary.entries_written} entr${summary.entries_written === 1 ? "y" : "ies"} to ${summary.output_path}` +
        (summary.god_matches > 0 ? `\nLabeled ${summary.god_matches} GOD game folder${summary.god_matches === 1 ? "" : "s"} with their title.` : "") +
        (summary.content_type_matches > 0 ? `\nLabeled ${summary.content_type_matches} content-type folder${summary.content_type_matches === 1 ? "" : "s"}.` : "") +
        (summary.dlc_matches > 0 ? `\nLabeled ${summary.dlc_matches} DLC file${summary.dlc_matches === 1 ? "" : "s"} with its name.` : "");
    }
  } catch (err) {
    resultArea.hidden = false;
    resultArea.className = "error";
    resultArea.textContent = `Error: ${err}`;
  }

  el("pick-root").disabled = false;
  updateOutputFieldAvailability();
}

init();
