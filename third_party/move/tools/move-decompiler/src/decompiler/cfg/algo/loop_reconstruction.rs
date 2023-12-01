// Copyright (c) Verichains, 2023

use std::collections::{BTreeSet, HashMap, HashSet, VecDeque};

use super::{
    super::datastructs::*,
    scc::{Graph, TarjanScc},
};

pub fn loop_reconstruction<BlockContent: BlockContentTrait>(
    bbs: &mut Vec<BasicBlock<usize, BlockContent>>,
) -> Result<(), anyhow::Error> {
    let mut full_view = HashSet::<usize>::new();
    for i in 0..bbs.len() {
        full_view.insert(i);
    }
    loop_reconstruction_recursive(bbs, bbs.len(), &full_view, 0)
}

fn loop_reconstruction_recursive<BlockContent: BlockContentTrait>(
    bbs: &mut Vec<BasicBlock<usize, BlockContent>>,
    original_len: usize,
    current_view: &HashSet<usize>,
    start_idx: usize,
) -> Result<(), anyhow::Error> {
    let graph = build_graph(bbs, current_view, start_idx);
    if graph.nodes().len() == 0 {
        return Ok(());
    }
    let scc = TarjanScc::new(&graph);

    let mut scc_super_graph = Graph::new();
    let mut scc_super_graph_node_entries = HashMap::<usize, HashSet<usize>>::new();
    let mut scc_super_graph_node_exits = HashMap::<usize, HashSet<usize>>::new();

    let scc_super_graph_exit_node = usize::MAX;

    for u in 0..bbs.len() {
        if !current_view.contains(&u) {
            continue;
        }
        if let Some((scc_id, _)) = scc.scc_for_node(u) {
            for &v in bbs[u].next.next_blocks() {
                // v is reachable so it's safe to unwrap
                let v_scc_id = if let Some((v_scc_id, _)) = scc.scc_for_node(v) {
                    v_scc_id
                } else {
                    // v is not visible
                    // make a fake scc for this node, so we can add an edge to the exit node
                    scc_super_graph_exit_node
                };
                if scc_id != v_scc_id {
                    scc_super_graph.add_edge(scc_id, v_scc_id);
                    scc_super_graph_node_entries
                        .entry(v_scc_id)
                        .or_insert(HashSet::new())
                        .insert(v);
                    scc_super_graph_node_exits
                        .entry(scc_id)
                        .or_insert(HashSet::new())
                        .insert(v);
                }
            }
        }
    }

    if current_view.contains(&start_idx) {
        let root_scc_id = scc.scc_for_node(start_idx).unwrap().0;
        scc_super_graph_node_entries
            .entry(root_scc_id)
            .or_insert(HashSet::new())
            .insert(start_idx);
    } else {
        for possible_root in find_possible_root(bbs, start_idx, current_view)? {
            let root_scc_id = scc.scc_for_node(possible_root).unwrap().0;
            scc_super_graph_node_entries
                .entry(root_scc_id)
                .or_insert(HashSet::new())
                .insert(possible_root);
        }
    }

    // validate the scc's
    for (scc_idx, scc_nodes) in scc.sccs() {
        if scc_nodes.len() == 1 {
            let node: usize = *scc_nodes.iter().next().unwrap();
            // if this node has self-loop, consider it as a loop
            if !bbs[node].next.next_blocks().iter().any(|x| **x == node) {
                continue;
            }
        }
        let entries_count = if let Some(entries) = scc_super_graph_node_entries.get(&scc_idx) {
            entries.len()
        } else {
            0
        };
        if entries_count > 1 {
            return Err(anyhow::anyhow!("Found SCC with multiple entries"));
        }
        if entries_count == 0 {
            return Err(anyhow::anyhow!(
                "Found non-entry SCC without entry (dead block)"
            ));
        }
        // let max_node = scc_nodes.iter().fold(0, |max_node, &i| {
        //     if bbs[i].idx > max_node {
        //         bbs[i].idx
        //     } else {
        //         max_node
        //     }
        // });
        // let exit_count = if let Some(exits) = scc_super_graph_node_exits.get(&scc_idx) {
        //     exits.iter().filter(|&&x| x > max_node).count()
        // } else {
        //     0
        // };
        // if exit_count > 1 {
        //     return Err(anyhow::anyhow!("Found SCC with multiple exits"));
        // }
    }

    // each scc is a loop, reconstruct them
    let empty_hashset = HashSet::<usize>::new();
    for (scc_idx, scc_nodes) in scc.sccs() {
        if scc_nodes.len() == 1 {
            let node: usize = *scc_nodes.iter().next().unwrap();
            if !bbs[node].next.next_blocks().iter().any(|x| **x == node) {
                continue;
            }
        }
        let scc_entries = scc_super_graph_node_entries.get(&scc_idx).unwrap();
        let scc_exits = scc_super_graph_node_exits
            .get(&scc_idx)
            .unwrap_or(&empty_hashset);
        let scc_exits = scc_exits.clone();
        let scc_entry = *scc_entries.iter().next().unwrap();

        let mut scc_exit = usize::MAX;
        if scc_exits.len() > 1 {
            if let Terminator::IfElse { else_block, .. } = bbs[scc_entry].next {
                if scc_exits.contains(&else_block) {
                    scc_exit = else_block;
                }
            }
            if scc_exit == usize::MAX {
                // heuristic: pick the exit with the largest offset
                scc_exit = scc_exits
                    .iter()
                    .fold((0, 0), |(max_offset, current_exit), &i| {
                        if bbs[i].offset > max_offset {
                            (bbs[i].offset, bbs[i].idx)
                        } else {
                            (max_offset, current_exit)
                        }
                    })
                    .1;

                // the heuristic above is not always correct if the binary is hand-made
                // if cfg!(debug_assertions) {
                //     return Err(anyhow::anyhow!(
                //         "Failed to reconstruct loop, multiple exits {:?}",
                //         scc_exits
                //     ));
                // } else {
                //     return Err(anyhow::anyhow!(
                //         "Failed to reconstruct loop, multiple exits"
                //     ));
                // }
            }
        }
        if scc_exit == usize::MAX && scc_exits.len() == 1 {
            scc_exit = *scc_exits.iter().next().unwrap();
        }

        let mut new_blocks: Vec<BasicBlock<usize, BlockContent>> = Vec::new();
        let mut next_block_idx = bbs.len();

        let mut dummy_break = HashMap::<usize, usize>::new();
        let mut dummy_continue = HashMap::<usize, usize>::new();

        let mut add_dummy_block_if_required = |base: usize, x: usize| {
            let mut x: usize = x;
            x = if x == scc_entry {
                if let Some(&id) = dummy_continue.get(&base) {
                    id
                } else {
                    let id = next_block_idx;
                    next_block_idx += 1;
                    let mut new_block: BasicBlock<usize, BlockContent> = Default::default();
                    new_block.idx = id;
                    new_block.offset = usize::MAX;
                    new_block.topo_priority = Some(0);
                    new_block.topo_after = HashSet::from([base]);
                    new_block.topo_before = HashSet::from([scc_exit]);
                    new_block.next = Terminator::Continue { target: scc_entry };

                    new_blocks.push(new_block);
                    dummy_continue.insert(base, id);
                    id
                }
            } else {
                x
            };
            x = if x == scc_exit {
                if let Some(&id) = dummy_break.get(&base) {
                    id
                } else {
                    let id = next_block_idx;
                    next_block_idx += 1;

                    let mut new_block: BasicBlock<usize, BlockContent> = Default::default();
                    new_block.idx = id;
                    new_block.offset = usize::MAX;
                    new_block.topo_priority = Some(0);
                    new_block.topo_after = HashSet::from([base]);
                    new_block.topo_before = HashSet::from([scc_exit]);
                    new_block.next = Terminator::Break { target: scc_exit };
                    new_blocks.push(new_block);

                    dummy_break.insert(base, id);
                    id
                }
            } else {
                x
            };
            x
        };

        for &i in scc_nodes.iter() {
            let b = &mut bbs[i];
            match b.next {
                Terminator::Branch { target } => {
                    if target == scc_entry {
                        b.next = Terminator::Continue { target };
                    };
                    if target == scc_exit {
                        b.next = Terminator::Break { target };
                    };
                }
                Terminator::IfElse {
                    if_block,
                    else_block,
                } => {
                    if b.idx != scc_entry {
                        b.next = Terminator::IfElse {
                            if_block: add_dummy_block_if_required(i, if_block),
                            else_block: add_dummy_block_if_required(i, else_block),
                        };
                    }
                }
                _ => {}
            }
        }

        let mut body_view = HashSet::<usize>::new();
        // new blocks only contain break and continue, all of them jump to body's external nodes,
        // so from the body's point of view, adding them or not doesn't change anything
        for &i in scc_nodes.iter() {
            if i != scc_entry {
                body_view.insert(i);
            }
        }

        // check the entry
        let mut is_valid_conditioned_entry = true;
        if let Terminator::IfElse {
            if_block,
            else_block,
        } = bbs[scc_entry].next
        {
            if !scc_nodes.contains(&if_block) && if_block != scc_exit {
                if cfg!(debug_assertions) {
                    return Err(anyhow::anyhow!(
                        "Failed to reconstruct loop, entry node {:?} is not in SCC {:?}",
                        if_block,
                        scc_nodes
                    ));
                } else {
                    return Err(anyhow::anyhow!(
                        "Failed to reconstruct loop, entry node is not in SCC"
                    ));
                }
            }
            if else_block != scc_exit {
                is_valid_conditioned_entry = false;
            }
        } else {
            is_valid_conditioned_entry = false;
        }

        if is_valid_conditioned_entry {
            if let Terminator::IfElse {
                if_block,
                else_block,
            } = bbs[scc_entry].next
            {
                bbs[scc_entry].next = Terminator::While {
                    inner_block: if_block,
                    outer_block: else_block,
                };
            } else {
                unreachable!();
            }
        } else {
            bbs[scc_entry].unconditional_loop_entry = Some(scc_exit);
        }

        bbs.append(&mut new_blocks);

        if body_view.len() > 0 {
            loop_reconstruction_recursive(bbs, original_len, &body_view, scc_entry)?;
        }
    }

    Ok(())
}

fn find_possible_root<BlockContent: BlockContentTrait>(
    bbs: &mut Vec<BasicBlock<usize, BlockContent>>,
    start_idx: usize,
    current_view: &HashSet<usize>,
) -> Result<HashSet<usize>, anyhow::Error> {
    let mut possible_roots = HashSet::<usize>::new();
    for &v in bbs[start_idx].next.next_blocks() {
        if current_view.contains(&v) {
            possible_roots.insert(v);
        }
    }
    Ok(possible_roots)
}

fn build_graph<BlockContent: BlockContentTrait>(
    blocks: &[BasicBlock<usize, BlockContent>],
    current_view: &HashSet<usize>,
    starting_idx: usize,
) -> Graph {
    let mut graph = Graph::new();
    let mut visited = BTreeSet::<usize>::new();
    let mut queue = VecDeque::<usize>::new();
    queue.push_back(starting_idx);
    visited.insert(starting_idx);
    // let mut current_view = current_view.clone();
    // current_view.insert(starting_idx);
    if current_view.contains(&starting_idx) {
        graph.ensure_node(starting_idx);
    }
    while let Some(idx) = queue.pop_front() {
        for &&nxt in blocks[idx].next.next_blocks().iter() {
            if !current_view.contains(&nxt) {
                continue;
            }
            if current_view.contains(&idx) {
                graph.add_edge(idx, nxt);
            }
            if visited.insert(nxt) {
                queue.push_back(nxt);
            }
        }
    }
    graph
}
