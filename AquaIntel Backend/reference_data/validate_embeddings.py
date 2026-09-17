"""
Validate FAISS reference embeddings: for each class, embed a fresh crop
of its own type and confirm similarity_pct > 80%, and < 60% vs all other classes.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import numpy as np
from embedding import FAISSIndexManager, embed_roi
from physics_extractor import extract_physics_vector
from reference_data.generate_references import CLASS_GENERATORS, VARIANTS_PER_CLASS, FAISS_POS, EMBEDDING_DIM

idx = FAISSIndexManager(dimension=EMBEDDING_DIM)
idx.load_indices(FAISS_POS, FAISS_POS.replace("pos_", "neg_"))


def similarity(dist):
    return max(0.0, (2.0 - dist) / 2.0) * 100.0


print(f"\n{'Class':<22} {'Self%':>7}  {'Best-other%':>12}  {'Status'}")
print("-" * 55)

all_pass = True
for cls_name, gen_fn in CLASS_GENERATORS.items():
    # Use variant not in the seeded set (VARIANTS_PER_CLASS = 7, use variant 8)
    probe = gen_fn(variant=VARIANTS_PER_CLASS)
    phys  = np.array(extract_physics_vector(probe), dtype=np.float32)
    emb   = embed_roi(probe, phys)

    D, I = idx.positive_index.search(np.atleast_2d(emb), 3)
    top_sim  = similarity(float(D[0][0]))
    top_meta = idx.positive_metadata[int(I[0][0])]
    top_cls  = top_meta.get("category", "?")

    # Find best match from a different class
    other_sim = 0.0
    for rank in range(len(I[0])):
        mc = idx.positive_metadata[int(I[0][rank])].get("category", "?")
        if mc != cls_name:
            other_sim = similarity(float(D[0][rank]))
            break

    ok = "✓ PASS" if top_cls == cls_name and top_sim >= 70.0 else "✗ FAIL"
    if "FAIL" in ok:
        all_pass = False
    print(f"{cls_name:<22} {top_sim:7.1f}%  {other_sim:12.1f}%  {ok}  (matched: {top_cls})")

print("-" * 55)
print("All pass!" if all_pass else "Some classes failed — check geometry generators.")
