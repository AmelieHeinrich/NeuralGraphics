//
//  RNG.h
//  Pocketcat
//
//  Created by Amélie Heinrich on 23/03/2026.
//

#ifndef RNG_H
#define RNG_H

struct RNG {
    uint state;

    uint next() {
        state = state * 747796405u + 2891336453u;
        uint w = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
        return (w >> 22u) ^ w;
    }

    float next_f() {
        return float(next()) / float(0xFFFFFFFFu);
    }
};

inline RNG make_rng(uint2 pid, uint frame) {
    RNG rng;
    uint h = pid.x * 1973u + pid.y * 9277u + frame * 26699u;
    rng.state = h ^ (h >> 16u);
    return rng;
}

#endif
