package main

import "core:fmt"
import "core:slice"
import "core:math/rand"

import "core:math/big"

// import "core:crypto/rsa"
import "./rsa"
import "core:crypto/hash"

Country :: enum {
    Ukraine,
    Russia,
    Poland,
}

Person :: struct {
    id : u64,
    fullname : string,
    country : Country,
    age : int,

    rememberedA : []u8,
    rememberedB : []u8,
    rememberedUid : u64,
    rememberedViolation : bool,

    key_prv : rsa.Key_Private,
    key_pub : rsa.Key_Public,
}

Candidate :: struct {
    id : u64,
    id_multipliers : [8]u8,

    fullname : string,

    votes : int,
}




Voter :: struct {
    person_id : u64,
    fullname : string,
    key_pub : rsa.Key_Public,
}

VoterSingle :: struct {
    person_id : u64,
    fullname : string,
    key_pub : rsa.Key_Public,

    ballot : Ballot,
    alreadyVoted : bool,
}



ElectionCommission :: struct {
    candidates : []Candidate,
    voters : [dynamic]Voter,

    key_prv : rsa.Key_Private,
    key_pub : rsa.Key_Public,

    ballots : [dynamic]PublicizedBallot,
}

MinorElectionCommission :: struct {
    voters : [dynamic]VoterSingle,
    ballots : [dynamic]SignedBallot,
    publicBallots : [dynamic]Ballot,
}




BallotPayload :: struct {
    candidate_id : u64,
}

Ballot :: struct {
    payload : []u8,
    id      : u64,
}

SignedBallot :: struct {
    ballot : Ballot,

    person_id : u64,
    signature : []u8,
}

PublicizedBallot :: struct {
    candidate_id : u64,
    id           : u64,
}



MINOR_EC_COUNT :: 2



main :: proc () {
    people : []Person = {
        Person{ id = 0, fullname = "Vitalya Gryb", country = .Ukraine, age = 23 },
        Person{ id = 1, fullname = "Svitlana Zhizha", country = .Ukraine, age = 27 },
        Person{ id = 2, fullname = "Zheka Zrada", country = .Ukraine, age = 19 },
        Person{ id = 3, fullname = "Grzegorz Brzeczyszczykiewicz", country = .Ukraine, age = 153 },
        Person{ id = 4, fullname = "little boy", country = .Ukraine, age = 4 },
        Person{ id = 5, fullname = "Yaroslav Aboba", country = .Ukraine, age = 34 },
        Person{ id = 6, fullname = "Vova Ugabuga", country = .Ukraine, age = 7182 },
        Person{ id = 7, fullname = "Mariya Kavun", country = .Ukraine, age = 26 },
    }



    for &p in people {
        p.key_prv, p.key_pub = rsa.keygen()
        fmt.printfln("Generated private key for %v", p.fullname)
    }
    fmt.println()



    // TODO: id multiplier thingy
    ec : ElectionCommission = {
        candidates = {
            Candidate{ fullname = "Petro Poroshenko", votes = 0 },
            Candidate{ fullname = "Amogus", votes = 0 },
        },
    }

    {
        b0 := cast(u8)rand.uint64_range(0, 256)
        b1 := cast(u8)rand.uint64_range(0, 256)
        for &c in ec.candidates {
            c.id = 1
            for &b, i in c.id_multipliers {
                if i == 0 { b = b0 }
                else if i == 1 { b = b1 }
                else { b = cast(u8)rand.uint64_range(0, 256) }

                c.id *= cast(u64)b
            }
        }
    }

    ec.key_prv, ec.key_pub = rsa.keygen()
    fmt.printfln("Generated private key for ELECTION COMMISSION")
    
    EC_PUBLIC_KEY := ec.key_pub
    fmt.println()

    fmt.println("List of candidates")
    for c in ec.candidates {
        fmt.printfln("%v | ID: %v (%v)", c.fullname, c.id, c.id_multipliers)
    }
    fmt.println()

    for i : int = 0; i < len(people); i += 1 {
        p := &people[i]


        fmt.printfln("Examining person %v", p.fullname)


        // context.user_ptr = &p.id
        // vi, vf := slice.linear_search_proc(rb.voters[:], proc (v : Voter) -> bool {
        //     return (v.person_id == (cast(^u64)context.user_ptr)^)
        // })
        //
        // if vf {
        //     fmt.printfln("\tDECLINED: Person already registered")
        //     continue
        // }



        if p.country != .Ukraine {
            fmt.printfln("\tINELIGIBLE: You have to be a citizen of Ukraine to vote")
            p.rememberedViolation = true
            continue
        }
        if p.age < 18 {
            fmt.printfln("\tINELIGIBLE: You have to be an adult to vote")
            p.rememberedViolation = true
            continue
        }

        voter := Voter{
            person_id = p.id,
            fullname = p.fullname,
            key_pub = p.key_pub,
        }

        append(&ec.voters, voter)
        fmt.printfln("\tVOTER REGISTERED")
    }
    fmt.println()


    fmt.println("List of eligible voters")
    for v in ec.voters {
        fmt.printfln("%v", v.fullname)
    }
    fmt.println()









    mecs : [MINOR_EC_COUNT]MinorElectionCommission
    for &m, i in mecs {
        for &v in ec.voters {
            vs := VoterSingle{
                person_id = v.person_id,
                fullname = v.fullname,
                key_pub = v.key_pub,

                ballot = {},
                alreadyVoted = false,
            }

            append(&m.voters, vs)
        }

        fmt.printfln("SENT VOTER DATA FROM CENTRAL ELECTION COMMISSION TO EC #%v", i)
    }
    fmt.println()





    fmt.printfln("VOTING STARTED")
    for i : int = 0; i < len(people); i += 1 {
        p := &people[i]

        candidate := rand.choice(ec.candidates)
        fmt.printfln("Voter %v chooses candidate %v", p.fullname, candidate.fullname)

        muls_a : [8]u8
        muls_b : [8]u8

        for &b, i in candidate.id_multipliers {
            divisors : [dynamic]u8
            defer delete(divisors)

            for div in 1 ..< 256 {
                if b % cast(u8)div == 0 { append(&divisors, cast(u8)div) }
            }

            div_a := rand.choice(divisors[:])
            div_b := b / div_a
            assert(div_a * div_b == b)

            muls_a[i] = div_a
            muls_b[i] = div_b
        }

        mul_a : u64 = 1
        mul_b : u64 = 1

        for x, i in soa_zip(a = muls_a[:], b = muls_b[:]) {
            mul_a *= cast(u64)x.a
            mul_b *= cast(u64)x.b
        }

        // violation: bad math
        if rand.float32() < 0.1 {
            mul_b += 5
            fmt.printfln("\tVIOLATION: Messing up math")
            p.rememberedViolation = true
        }

        multipliers : []u64 = { mul_a, mul_b }
        
        fmt.printfln("\tGenerated multipliers: %v * %v == %v", mul_a, mul_b, mul_a * mul_b)

        voteId := rand.uint64()

        fmt.printfln("\tGenerated ID: %v", voteId)


        // violation: impersionation and thus invalid signature
        impersonating := false
        another := rand.choice(ec.voters[:])
        if rand.float32() < 0.1 {
            if another.person_id != p.id {
                fmt.printfln("\tVIOLATION: Decided to impersonate %v", another.fullname)
                p.rememberedViolation = true
                impersonating = true
            }
        }

        p.rememberedUid = voteId

        for &x, i in soa_zip(mec = mecs[:], mul = multipliers) {
            payload := BallotPayload{ candidate_id = x.mul }
            epayload, result := rsa.encrypt_value(&EC_PUBLIC_KEY, payload)
            if !result {
                fmt.printfln("\tFATAL: Encryption failed")
            }

            if i == 0 {
                p.rememberedA = epayload
            }
            else {
                p.rememberedB = epayload
            }

            ballot := Ballot{
                payload = epayload,
                id = voteId,
            }

            // violation: messing up IDs
            if rand.float32() < 0.1 {
                fmt.printfln("\tVIOLATION: Messing up ID")
                ballot.id = rand.uint64()
                p.rememberedViolation = true
            }

            signedBallot := SignedBallot{
                ballot = ballot,

                person_id = p.id,
                signature = rsa.sign_value(&p.key_prv, ballot),
            }

            if impersonating {
                signedBallot.person_id = another.person_id
            }

            append(&x.mec.ballots, signedBallot)

            fmt.printfln("\tSent partial ballot to MEC #%v", i)
        }
    }
    fmt.println("VOTING ENDED")
    fmt.println()




    fmt.println("VALIDATING VOTES")
    for &mec, i in mecs {
        fmt.printfln("============\nMINOR ELECTION COMMISSION #%v\n============", i)

        for &sb, i in mec.ballots {
            fmt.printfln("Examining ballot #%v", i)

            context.user_ptr = &sb.person_id
            vi, vf := slice.linear_search_proc(mec.voters[:], proc (v : VoterSingle) -> bool {
                return (v.person_id == (cast(^u64)context.user_ptr)^)
            })

            if !vf {
                fmt.printfln("\tDISMISSED: Voter with id %v doesn't exist", sb.person_id)
                continue;
            }

            fmt.printfln("\tINFO: Ballot from %v with ID %v", mec.voters[vi].fullname, sb.ballot.id)

            if !rsa.verify_value(&mec.voters[vi].key_pub, sb.ballot, sb.signature) {
                fmt.printfln("\tDISMISSED: Failed to ensure ballot's authenticity")
                continue;
            }


            if mec.voters[vi].alreadyVoted {
                fmt.printfln("\tDISMISSED: Person already voted")
                continue;
            }


            context.user_ptr = &sb.ballot.id
            _, bf := slice.linear_search_proc(mec.publicBallots[:], proc (b : Ballot) -> bool {
                return (b.id == (cast(^u64)context.user_ptr)^)
            })

            if bf {
                fmt.printfln("\tDISMISSED: Duplicate ID")
                continue;
            }


            // violation: replacing ballot
            if rand.float32() < 0.1 {
                value : u64 = rand.uint64()
                sb.ballot.payload, _ = rsa.encrypt_value(&EC_PUBLIC_KEY, BallotPayload{ value })
                fmt.printfln("\tVIOLATION: Changed multiplier because im evil")
            }


            mec.voters[vi].alreadyVoted = true
            append(&mec.publicBallots, sb.ballot)
            fmt.println("\tBALLOT ACCEPTED")
        }
    }
    fmt.println()




    fmt.println("COUNTING VOTES")
    allBallots : [dynamic]Ballot
    for &mec in mecs {
        append(&allBallots, ..mec.publicBallots[:])
    }

    slice.sort_by(allBallots[:], proc (i, j : Ballot) -> bool { return i.id < j.id })
    ids := slice.mapper(allBallots[:], proc (b : Ballot) -> u64 { return b.id })
    ids = slice.unique(ids)

    publishedBallots : [dynamic]PublicizedBallot

    for &id in ids {
        fmt.printfln("Examining ID %v", id)

        context.user_ptr = &id
        ballots := slice.filter(allBallots[:], proc (b : Ballot) -> bool { return b.id == (cast(^u64)context.user_ptr)^ })
        defer delete(ballots)
        if len(ballots) != 2 {
            fmt.printfln("\tDISMISSED: Found %v ballots with this ID", len(ballots))
            continue
        }

        int_a := rsa.int_from_bytes(ballots[0].payload)
        int_b := rsa.int_from_bytes(ballots[1].payload)
        int_c : big.Int
        defer big.destroy(&int_a, &int_b, &int_c)
        big.internal_mulmod(&int_c, &int_a, &int_b, &EC_PUBLIC_KEY.n)
        payload := rsa.bytes_from_int(&int_c)
        defer delete(payload)

        candidate_id, result_decrypt := rsa.decrypt_value(&ec.key_prv, payload, BallotPayload) 
        if !result_decrypt {
            fmt.printfln("\tDISMISSED: Decryption failed")
            continue
        }

        fmt.printfln("\tINFO: Restored ID: %v", candidate_id.candidate_id)

        context.user_ptr = &candidate_id.candidate_id
        ci, cf := slice.linear_search_proc(ec.candidates[:], proc (c : Candidate) -> bool {
            return (c.id == (cast(^u64)context.user_ptr)^)
        })

        if !cf {
            fmt.printfln("\tDISMISSED: Invalid candidate ID %v", candidate_id.candidate_id)
            continue
        }

        fmt.printfln("\tINFO: Voted for %v", ec.candidates[ci].fullname)
        ec.candidates[ci].votes += 1
        append(&publishedBallots, PublicizedBallot{
            candidate_id = candidate_id.candidate_id,
            id = id,
        })
    }
    fmt.println()



    fmt.printfln("ELECTION RESULTS:")
    for c in ec.candidates {
        fmt.printfln("%v:\n\t%v votes", c.fullname, c.votes)
    }


    fmt.printfln("BALLOTS:")
    for &pb in publishedBallots {
        context.user_ptr = &pb.candidate_id
        ci, _ := slice.linear_search_proc(ec.candidates, proc (c : Candidate) -> bool { return (c.id == (cast(^u64)context.user_ptr)^) })

        fmt.printfln("\tID: %v | Candidate: %v", pb.id, ec.candidates[ci].fullname)
    }
    fmt.println()


    for &p in people {
        context.user_ptr = &p.rememberedUid
        _, bf := slice.linear_search_proc(publishedBallots[:], proc (b : PublicizedBallot) -> bool { return (b.id == (cast(^u64)context.user_ptr)^) })

        context.user_ptr = &p.rememberedUid
        pa, paf := slice.linear_search_proc(mecs[0].publicBallots[:], proc (b : Ballot) -> bool { return (b.id == (cast(^u64)context.user_ptr)^) })
        paf = paf && slice.equal(mecs[0].publicBallots[pa].payload, p.rememberedA)

        context.user_ptr = &p.rememberedUid
        pb, pbf := slice.linear_search_proc(mecs[1].publicBallots[:], proc (b : Ballot) -> bool { return (b.id == (cast(^u64)context.user_ptr)^) })
        pbf = pbf && slice.equal(mecs[1].publicBallots[pb].payload, p.rememberedB)

        fmt.printfln("%v verification status:\n\tA - %v, B - %v, FINAL - %v",
            p.fullname,
            paf ? "O" : "X",
            pbf ? "O" : "X",
            bf  ? "O" : "X")

        if (!bf || !paf || !pbf) && p.rememberedViolation {
            fmt.printfln("\t(keep in mind they violated voting process)")
        }
    }
}
