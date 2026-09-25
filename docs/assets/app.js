const realTasks = [
  {
    title: "Pick Carrot into Pot",
    skill: "Pick-and-place",
    clips: { success: "assets/videos/real/pick_place_success.m4v" },
  },
  {
    title: "Press Button",
    skill: "Contact-rich actuation",
    clips: {
      success: "assets/videos/real/press_button_success.m4v",
      failure: "assets/videos/real/press_button_failure.m4v",
    },
  },
  {
    title: "Push Pot into Marked Region",
    skill: "Goal-directed pushing",
    clips: {
      success: "assets/videos/real/push_pot_success_1.m4v",
      "success 2": "assets/videos/real/push_pot_success_2.m4v",
    },
  },
  {
    title: "Open Pot by Lifting the Lid",
    skill: "Grasp-and-lift",
    clips: {
      success: "assets/videos/real/open_lid_success.m4v",
      failure: "assets/videos/real/open_lid_failure.m4v",
    },
  },
];

function labelForClip(name) {
  if (name.startsWith("success")) return "Success" + name.slice(7);
  if (name === "failure") return "Failure";
  return name;
}

function taskCard(task) {
  const entries = Object.entries(task.clips);
  const article = document.createElement("article");
  article.className = "video-card";

  const media = document.createElement("div");
  media.className = "video-frame";
  const video = document.createElement("video");
  video.controls = true;
  video.muted = true;
  video.playsInline = true;
  video.preload = "metadata";
  video.setAttribute("aria-label", `${task.title} rollout`);
  const empty = document.createElement("div");
  empty.className = "media-empty";
  empty.textContent = "Video unavailable.";
  empty.hidden = true;
  media.append(video, empty);

  const meta = document.createElement("div");
  meta.className = "video-meta";
  const heading = document.createElement("div");
  heading.className = "video-heading";
  const title = document.createElement("h3");
  title.textContent = task.title;
  const badge = document.createElement("span");
  badge.className = "badge";
  heading.append(title, badge);
  const detail = document.createElement("p");
  detail.textContent = task.skill;

  const tabs = document.createElement("div");
  tabs.className = "media-tabs";
  entries.forEach(([name, src], index) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `media-tab${index === 0 ? " is-active" : ""}`;
    button.textContent = labelForClip(name);
    button.addEventListener("click", () => selectClip(name, src));
    tabs.append(button);
  });

  function selectClip(name, src) {
    tabs.querySelectorAll(".media-tab").forEach((button) => {
      button.classList.toggle("is-active", button.textContent === labelForClip(name));
    });
    empty.hidden = true;
    video.hidden = false;
    video.src = src;
    video.load();
    const successful = name.startsWith("success");
    badge.className = `badge ${successful ? "success" : "failure"}`;
    badge.textContent = labelForClip(name);
  }

  video.addEventListener("error", () => {
    video.hidden = true;
    empty.hidden = false;
    badge.className = "badge pending";
    badge.textContent = "Unavailable";
  });

  meta.append(heading, detail, tabs);
  article.append(media, meta);
  selectClip(entries[0][0], entries[0][1]);
  return article;
}

const realGrid = document.querySelector("#real-grid");
realTasks.forEach((task) => realGrid.append(taskCard(task)));

document.addEventListener("play", (event) => {
  if (event.target.tagName !== "VIDEO") return;
  document.querySelectorAll("video").forEach((video) => {
    if (video !== event.target) video.pause();
  });
}, true);
