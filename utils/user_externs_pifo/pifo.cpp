#include "pifo.h"
#include <bm/bm_sim/logger.h>
#include <queue>

namespace bm {

std::vector<std::shared_ptr<pifo_scheduler::flow_scheduler>> pifo_scheduler::FS = { NULL};

std::vector<std::shared_ptr<pifo_scheduler::fifo_bank>> pifo_scheduler::FB = { NULL};

unsigned int pifo_scheduler::time_now = 0;
unsigned int pifo_scheduler::number_levels = 1;

std::vector<unsigned int> pifo_scheduler::number_of_queues_per_level = {1};
std::vector<unsigned int> pifo_scheduler::number_of_pkts_per_queue_each_level = {1000};

unsigned int sum_all_queues = pifo_scheduler::number_of_queues_per_level[0];

unsigned int number_of_update_ranks_all_level = (pifo_scheduler::number_of_pkts_per_queue_each_level[0]*pifo_scheduler::number_of_queues_per_level[0] * pifo_scheduler::number_levels);

std::vector<unsigned int> pifo_scheduler::new_ranks_each_level(number_of_update_ranks_all_level);

unsigned int pifo_scheduler::pkt_ptr = 0;
unsigned int pifo_scheduler::shaping = 0;
unsigned int pifo_scheduler::number_of_enqueue_packets = 0;
std::vector<unsigned int> pifo_scheduler::pkt_levels_ranks = {0};
unsigned int pifo_scheduler::switch_is_ready = 1;
unsigned int pifo_scheduler::number_of_read_packets = 0;
unsigned int pifo_scheduler::number_of_dequeue_packets = 0;
std::queue<unsigned int> pifo_scheduler::pkt_ptr_queue;

int pifo_scheduler::start_time = 0;
int pifo_scheduler::last_time = 0;

BM_REGISTER_EXTERN(pifo_scheduler)
BM_REGISTER_EXTERN_METHOD(pifo_scheduler, my_scheduler, const Data&, const Data&, const Data&, const Data&, const Data&, const Data&, const Data&, const Data&, const Data&);

BM_REGISTER_EXTERN_METHOD(pifo_scheduler, pass_rank_values, const Data&, const Data&);

BM_REGISTER_EXTERN_METHOD(pifo_scheduler, pass_updated_rank_values, const Data&, const Data&, const Data&);

}  // namespace bm

int import_pifo(){
  return 0;
}
