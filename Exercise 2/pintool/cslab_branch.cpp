#include "pin.H"

#include <iostream>
#include <fstream>
#include <cassert>

using namespace std;

#include "branch_predictor.h"
#include "pentium_m_predictor/pentium_m_branch_predictor.h"
#include "ras.h"

/* ===================================================================== */
/* Commandline Switches                                                  */
/* ===================================================================== */
KNOB<string> KnobOutputFile(KNOB_MODE_WRITEONCE, "pintool",
                            "o", "cslab_branch.out", "specify output file name");
/* ===================================================================== */

/* ===================================================================== */
/* Global Variables                                                      */
/* ===================================================================== */
std::vector<BranchPredictor *> branch_predictors;
typedef std::vector<BranchPredictor *>::iterator bp_iterator_t;

//> BTBs have slightly different interface (they also have target predictions)
//  so we need to have different vector for them.
std::vector<BTBPredictor *> btb_predictors;
typedef std::vector<BTBPredictor *>::iterator btb_iterator_t;

std::vector<RAS *> ras_vec;
typedef std::vector<RAS *>::iterator ras_vec_iterator_t;

UINT64 total_instructions;
std::ofstream outFile;

/* ===================================================================== */

INT32 Usage()
{
    cerr << "This tool simulates various branch predictors.\n\n";
    cerr << KNOB_BASE::StringKnobSummary();
    cerr << endl;
    return -1;
}

/* ===================================================================== */

VOID count_instruction()
{
    total_instructions++;
}

VOID call_instruction(ADDRINT ip, ADDRINT target, UINT32 ins_size)
{
    ras_vec_iterator_t ras_it;

    for (ras_it = ras_vec.begin(); ras_it != ras_vec.end(); ++ras_it)
    {
        RAS *ras = *ras_it;
        ras->push_addr(ip + ins_size);
    }
}

VOID ret_instruction(ADDRINT ip, ADDRINT target)
{
    ras_vec_iterator_t ras_it;

    for (ras_it = ras_vec.begin(); ras_it != ras_vec.end(); ++ras_it)
    {
        RAS *ras = *ras_it;
        ras->pop_addr(target);
    }
}

VOID cond_branch_instruction(ADDRINT ip, ADDRINT target, BOOL taken)
{
    bp_iterator_t bp_it;
    BOOL pred;

    for (bp_it = branch_predictors.begin(); bp_it != branch_predictors.end(); ++bp_it)
    {
        BranchPredictor *curr_predictor = *bp_it;
        pred = curr_predictor->predict(ip, target);
        curr_predictor->update(pred, taken, ip, target);
    }
}

VOID branch_instruction(ADDRINT ip, ADDRINT target, BOOL taken)
{
    btb_iterator_t btb_it;
    BOOL pred;

    for (btb_it = btb_predictors.begin(); btb_it != btb_predictors.end(); ++btb_it)
    {
        BTBPredictor *curr_predictor = *btb_it;
        pred = curr_predictor->predict(ip, target);
        curr_predictor->update(pred, taken, ip, target);
    }
}

VOID Instruction(INS ins, void *v)
{
    if (INS_Category(ins) == XED_CATEGORY_COND_BR)
        INS_InsertCall(ins, IPOINT_BEFORE, (AFUNPTR)cond_branch_instruction,
                       IARG_INST_PTR, IARG_BRANCH_TARGET_ADDR, IARG_BRANCH_TAKEN,
                       IARG_END);
    else if (INS_IsCall(ins))
        INS_InsertCall(ins, IPOINT_BEFORE, (AFUNPTR)call_instruction,
                       IARG_INST_PTR, IARG_BRANCH_TARGET_ADDR,
                       IARG_UINT32, INS_Size(ins), IARG_END);
    else if (INS_IsRet(ins))
        INS_InsertCall(ins, IPOINT_BEFORE, (AFUNPTR)ret_instruction,
                       IARG_INST_PTR, IARG_BRANCH_TARGET_ADDR, IARG_END);

    // For BTB we instrument all branches except returns
    if (INS_IsBranch(ins) && !INS_IsRet(ins))
        INS_InsertCall(ins, IPOINT_BEFORE, (AFUNPTR)branch_instruction,
                       IARG_INST_PTR, IARG_BRANCH_TARGET_ADDR, IARG_BRANCH_TAKEN,
                       IARG_END);

    // Count each and every instruction
    INS_InsertCall(ins, IPOINT_BEFORE, (AFUNPTR)count_instruction, IARG_END);
}

/* ===================================================================== */

VOID Fini(int code, VOID *v)
{
    bp_iterator_t bp_it;
    // btb_iterator_t btb_it;
    //  ras_vec_iterator_t ras_it;

    // Report total instructions and total cycles
    outFile << "Total Instructions: " << total_instructions << "\n";
    outFile << "\n";

    // outFile << "RAS: (Correct - Incorrect)\n";
    // for (ras_it = ras_vec.begin(); ras_it != ras_vec.end(); ++ras_it)
    // {
    //     RAS *ras = *ras_it;
    //     outFile << ras->getNameAndStats() << "\n";
    // }
    // outFile << "\n";

    outFile << "Branch Predictors: (Name - Correct - Incorrect)\n";
    for (bp_it = branch_predictors.begin(); bp_it != branch_predictors.end(); ++bp_it)
    {
        BranchPredictor *curr_predictor = *bp_it;
        outFile << "  " << curr_predictor->getName() << ": "
                << curr_predictor->getNumCorrectPredictions() << " "
                << curr_predictor->getNumIncorrectPredictions() << "\n";
    }
    outFile << "\n";

    // outFile << "BTB Predictors: (Name - Correct - Incorrect - TargetCorrect)\n";
    // for (btb_it = btb_predictors.begin(); btb_it != btb_predictors.end(); ++btb_it)
    // {
    //     BTBPredictor *curr_predictor = *btb_it;
    //     outFile << "  " << curr_predictor->getName() << ": "
    //             << curr_predictor->getNumCorrectPredictions() << " "
    //             << curr_predictor->getNumIncorrectPredictions() << " "
    //             << curr_predictor->getNumCorrectTargetPredictions() << "\n";
    // }

    outFile.close();
}

/* ===================================================================== */

VOID InitPredictors()
{
    // 4.2.i
    //  for (int i = 1; i <= 4; i++)
    //  {
    //      NbitPredictor *nbitPred = new NbitPredictor(14, i);
    //      branch_predictors.push_back(nbitPred);
    //  }
    //  TwoBitFSMPredictor *twoBitFSMPred = new TwoBitFSMPredictor(14, 2);
    //  branch_predictors.push_back(twoBitFSMPred);

    // 4.2.ii
    //  NbitPredictor *nbitPred1 = new NbitPredictor(15, 1);
    //  branch_predictors.push_back(nbitPred1);
    //  NbitPredictor *nbitPred2 = new NbitPredictor(14, 2);
    //  branch_predictors.push_back(nbitPred2);
    //  NbitPredictor *nbitPred4 = new NbitPredictor(13, 4);
    //  branch_predictors.push_back(nbitPred4);
    //  TwoBitFSMPredictor *twoBitFSMPred = new TwoBitFSMPredictor(14, 2);
    //  branch_predictors.push_back(twoBitFSMPred);

    // 4.3
    // BTBPredictor *btbPred = new BTBPredictor(512, 1);
    // btb_predictors.push_back(btbPred);
    // BTBPredictor *btbPred1 = new BTBPredictor(512, 2);
    // btb_predictors.push_back(btbPred1);
    // BTBPredictor *btbPred2 = new BTBPredictor(256, 2);
    // btb_predictors.push_back(btbPred2);
    // BTBPredictor *btbPred3 = new BTBPredictor(256, 4);
    // btb_predictors.push_back(btbPred3);
    // BTBPredictor *btbPred4 = new BTBPredictor(128, 2);
    // btb_predictors.push_back(btbPred4);
    // BTBPredictor *btbPred5 = new BTBPredictor(128, 4);
    // btb_predictors.push_back(btbPred5);
    // BTBPredictor *btbPred6 = new BTBPredictor(64, 4);
    // btb_predictors.push_back(btbPred6);
    // BTBPredictor *btbPred7 = new BTBPredictor(64, 8);
    // btb_predictors.push_back(btbPred7);

    // // 4.5
    // int M[6] = {32, 64, 128, 256, 512, 1024};
    // int n[7] = {12, 22, 28, 34, 36, 59, 62};
    // for (int i = 0; i < 6; i++)
    // {
    //     for (int j = 0; j < 7; j++)
    //     {
    //         PerceptronPredictor *ptnPred = new PerceptronPredictor(M[i], n[j]);
    //         branch_predictors.push_back(ptnPred);
    //     }
    // }

    // 4.6

    // // Pentium-M predictor
    // PentiumMBranchPredictor *pentiumPredictor = new PentiumMBranchPredictor();
    // branch_predictors.push_back(pentiumPredictor);

    // // Static Taken Predictor
    // BranchPredictor *bp = new StaticTakenPredictor();
    // branch_predictors.push_back(bp);

    // // Static BackwardTaken-ForwardNotTaken Predictor
    // BTFNTPredictor *bp = new BTFNTPredictor();
    // branch_predictors.push_back(bp);

    // // N-bit Predictor (8K entries, 4 bits)
    // NbitPredictor *nbitPred = new NbitPredictor(13, 4);
    // branch_predictors.push_back(nbitPred);

    int n[3] = {12, 28, 36};
    int M[3] = {(n[0] + 1) * floor(log2(floor(1.93 * n[0] + 14))), (n[2] + 1) * floor(log2(floor(1.93 * n[1] + 14))), (n[2] + 1) * floor(log2(floor(1.93 * n[2] + 14)))};

    for (int i = 0; i < 2; i++)
    {
        PerceptronPredictor *ptnPred = new PerceptronPredictor(M[i], n[i]);
        branch_predictors.push_back(ptnPred);
    }
}

VOID InitRas()
{
    // 4.4
    UINT32 entries[6] = {4, 8, 16, 32, 48, 64};
    for (int i = 0; i < 6; i++)
        ras_vec.push_back(new RAS(entries[i]));
}

int main(int argc, char *argv[])
{
    PIN_InitSymbols();

    if (PIN_Init(argc, argv))
        return Usage();

    // Open output file
    outFile.open(KnobOutputFile.Value().c_str());

    // Initialize predictors and RAS vector
    InitPredictors();
    // InitRas();

    // Instrument function calls in order to catch __parsec_roi_{begin,end}
    INS_AddInstrumentFunction(Instruction, 0);

    // Called when the instrumented application finishes its execution
    PIN_AddFiniFunction(Fini, 0);

    // Never returns
    PIN_StartProgram();

    return 0;
}

/* ===================================================================== */
/* eof */
/* ===================================================================== */
