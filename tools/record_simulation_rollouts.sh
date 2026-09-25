#!/usr/bin/env bash
set -Eeuo pipefail

set +u
source /home/paichichi/miniconda3/etc/profile.d/conda.sh
conda activate tcc-core-parity
set -u

PROJECT_ROOT=/home/paichichi/projects/rvt-3d-policy-head-adaption
RVT_ROOT="${PROJECT_ROOT}/rvt"
TCC_ROOT=/home/paichichi/projects/TCC-core
DATA_ROOT=/home/paichichi/data/AGNOSTOS/unseen_tasks/test
POLICY_ROOT="${TCC_ROOT}/wsl_result/downstream_rvt2_lite_runs/hparam_search"
POLICY_NAME=hpsB_vit_imagenet_rho0p5_eps0p05_lr0p000075_qstep1_lq0p05_lsa1_lmv0p5_i40000
MODEL_FOLDER="${POLICY_ROOT}/${POLICY_NAME}/policy"
OUTPUT_ROOT="${TCC_ROOT}/wsl_result/project_page_simulation_vit"
SELECTED_ROOT="${OUTPUT_ROOT}/selected"

TASKS=(
  put_toilet_roll_on_stand
  put_knife_on_chopping_board
  close_fridge
  close_microwave
  close_laptop_lid
  phone_on_base
  toilet_seat_down
  lamp_off
  lamp_on
  put_books_on_bookshelf
  put_umbrella_in_umbrella_stand
  open_grill
  put_rubbish_in_bin
  take_usb_out_of_computer
  take_lid_off_saucepan
  take_plate_off_colored_dish_rack
  basketball_in_hoop
  scoop_with_spatula
  straighten_rope
  turn_oven_on
  beat_the_buzz
  water_plants
  unplug_charger
)

export PYTHONPATH="${PROJECT_ROOT}:${RVT_ROOT}/libs/RLBench:${RVT_ROOT}/libs/PyRep:${RVT_ROOT}/libs/YARR:${RVT_ROOT}/libs/peract_colab:${RVT_ROOT}/libs/peract:${RVT_ROOT}/libs/point-renderer:${PYTHONPATH:-}"
export PATH="${CONDA_PREFIX}/bin:${PATH}"
export COPPELIASIM_ROOT=/home/paichichi/software/CoppeliaSim_4_1_0
export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${COPPELIASIM_ROOT}:${LD_LIBRARY_PATH:-}"
export LD_PRELOAD="${COPPELIASIM_ROOT}/libcrypto.so.1.1:${COPPELIASIM_ROOT}/libssl.so.1.1"
export QT_QPA_PLATFORM_PLUGIN_PATH="${COPPELIASIM_ROOT}"
unset QT_QPA_PLATFORM QT_PLUGIN_PATH

test -s "${MODEL_FOLDER}/model_0.pth"
test -s "${MODEL_FOLDER}/args.yaml"
test -s "${MODEL_FOLDER}/exp_cfg.yaml"
test -s "${MODEL_FOLDER}/mvt_cfg.yaml"
test -d "${DATA_ROOT}"
command -v ffmpeg >/dev/null
mkdir -p "${SELECTED_ROOT}"

while pgrep -f 'eval_clip_rvt2_full_5090.sh' >/dev/null; do
  printf '%s WAITING_FOR_ACTIVE_EVAL\n' "$(date -Iseconds)"
  sleep 30
done

cd "${RVT_ROOT}"
for task in "${TASKS[@]}"; do
  success_out="${SELECTED_ROOT}/${task}_success.mp4"
  failure_out="${SELECTED_ROOT}/${task}_failure.mp4"
  if [[ -s "${success_out}" && -s "${failure_out}" ]]; then
    printf '%s SKIP_COMPLETE task=%s\n' "$(date -Iseconds)" "${task}"
    continue
  fi

  log_name="project_page_vit_${task}"
  generated_root="${MODEL_FOLDER}/eval/${log_name}"
  run_dir="${OUTPUT_ROOT}/${task}"
  video_dir="${generated_root}/model_0/videos"
  mkdir -p "${run_dir}"
  rm -rf "${generated_root}"

  printf '%s START task=%s\n' "$(date -Iseconds)" "${task}" | tee "${run_dir}/status.log"
  CUDA_VISIBLE_DEVICES=0 xvfb-run -a -e "${run_dir}/xvfb.log" \
    -s '-screen 0 1024x768x24 +extension GLX +render -noreset' \
    python -X faulthandler -u eval.py \
      --model-folder "${MODEL_FOLDER}" \
      --eval-datafolder "${DATA_ROOT}" \
      --tasks "${task}" \
      --eval-episodes 25 \
      --episode-length 25 \
      --log-name "${log_name}" \
      --device 0 \
      --headless \
      --model-name model_0.pth \
      --save-video \
      > "${run_dir}/stdout.log" 2>&1

  success_src="$(find "${video_dir}" -maxdepth 1 -type f -name "${task}_success_*.mp4" -print | sort | head -n 1 || true)"
  failure_src="$(find "${video_dir}" -maxdepth 1 -type f -name "${task}_fail_*.mp4" -print | sort | head -n 1 || true)"

  if [[ -n "${success_src}" ]]; then
    ffmpeg -hide_banner -loglevel error -y -i "${success_src}" -an \
      -c:v libx264 -preset medium -crf 24 -pix_fmt yuv420p \
      -movflags +faststart "${success_out}"
  fi
  if [[ -n "${failure_src}" ]]; then
    ffmpeg -hide_banner -loglevel error -y -i "${failure_src}" -an \
      -c:v libx264 -preset medium -crf 24 -pix_fmt yuv420p \
      -movflags +faststart "${failure_out}"
  fi

  printf '%s COMPLETE task=%s success=%s failure=%s\n' \
    "$(date -Iseconds)" "${task}" "$([[ -s "${success_out}" ]] && echo yes || echo no)" \
    "$([[ -s "${failure_out}" ]] && echo yes || echo no)" \
    | tee -a "${run_dir}/status.log"
  rm -rf "${generated_root}"
done

touch "${OUTPUT_ROOT}/CAPTURE_COMPLETE"
printf '%s ALL_COMPLETE\n' "$(date -Iseconds)"
