#!/usr/bin/env bash
set -exuo pipefail
IFS=$'\n\t'

BEAKER_LEADER_REPLICA_HOSTNAME=$1
shift

NUM_NODES=$1
shift

BEAKER_REPLICA_RANK=$1
shift

# Warm HF cache
mkdir -p /root/.cache
pushd /root/.cache
curl "https://storage.googleapis.com/dirkgr-public/huggingface_cache_v3.tar.gz" | tar --keep-newer-files -xzf -
popd
export HF_DATASETS_OFFLINE=1

torchrun \
  --nnodes ${NUM_NODES}:${NUM_NODES} \
  --nproc-per-node 8 \
  --rdzv_id=12347 \
  --rdzv_backend=static \
  --rdzv_endpoint=$BEAKER_LEADER_REPLICA_HOSTNAME:29400 \
  --node_rank=$BEAKER_REPLICA_RANK \
  --rdzv_conf="read_timeout=420" \
  scripts/train.py \
  configs/llamaish7-s3.yaml \
    --run_name=llamaish7-qk-norm-reorder-zloss \
    --wandb.name=llamaish7-qk-norm-reorder-zloss \
    --wandb.group=llamaish7-qk-norm-reorder-zloss \
    --model.flash_attention=true \
    --fsdp.wrapping_strategy=by_block_and_size \
    --fsdp.sharding_strategy=SHARD_GRAD_OP \
    --save_folder=runs/ \
    --activation_checkpointing=fine_grained \
    --fused_loss=true \
    --device_train_microbatch_size=1 \
    --global_train_batch_size=1024 \
    --save_interval=50 \
    --eval_interval=50 \
    --optimizer.metrics_log_interval=1 \
    --save_overwrite \
    --model.scale_emb_init \
    --model.attention_layer_norm=true \
    --model.norm_after=true \
    --softmax_auxiliary_loss=true
    #'--load_path=${path.last_checkpoint:s3://ai2-llm/checkpoints/OLMo-medium/llamaish7-qk-norm-reorder-zloss/}'
