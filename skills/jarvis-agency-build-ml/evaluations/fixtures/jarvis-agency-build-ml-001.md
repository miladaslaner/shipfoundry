# STORY-70 — ML: train + evaluate the harsh-braking classifier

Status: Refined
Type label: ml

## AC Snapshot (frozen at Refined)

### Architecture constraints (epic)
- Deployment model: a harsh-braking model served behind the platform API for regulated customers.
- Data provenance: training data is the licensed labelled-URL corpus; no customer PII in training.
- The model's decisions must be auditable (record the model version and input features).

### Acceptance criteria
- Given the labelled URL corpus, when the pipeline runs, then it trains a classifier and reports the held-out test metric.
- Given the held-out test set, then the model achieves at least 0.95 ROC-AUC, measured once on data the model never trained on. (metric + threshold)
- Given the train/validation/test split, then the three sets are disjoint (no leakage); a test asserts disjointness. (leakage)
- Given the same seed and config, when the pipeline re-runs, then it reproduces the same metric. (reproducibility)
- Given a trained model, then the model artifact and the dataset version are recorded for audit.
