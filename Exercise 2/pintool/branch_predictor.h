#ifndef BRANCH_PREDICTOR_H
#define BRANCH_PREDICTOR_H

#include <sstream> // std::ostringstream
#include <cmath>   // pow(), floor
#include <cstring> // memset()

/**
 * A generic BranchPredictor base class.
 * All predictors can be subclasses with overloaded predict() and update()
 * methods.
 **/
class BranchPredictor
{
public:
    BranchPredictor() : correct_predictions(0), incorrect_predictions(0){};
    ~BranchPredictor(){};

    virtual bool predict(ADDRINT ip, ADDRINT target) = 0;
    virtual void update(bool predicted, bool actual, ADDRINT ip, ADDRINT target) = 0;
    virtual string getName() = 0;

    UINT64 getNumCorrectPredictions() { return correct_predictions; }
    UINT64 getNumIncorrectPredictions() { return incorrect_predictions; }

    void resetCounters() { correct_predictions = incorrect_predictions = 0; };

protected:
    void updateCounters(bool predicted, bool actual)
    {
        if (predicted == actual)
            correct_predictions++;
        else
            incorrect_predictions++;
    };

private:
    UINT64 correct_predictions;
    UINT64 incorrect_predictions;
};

class NbitPredictor : public BranchPredictor
{
public:
    NbitPredictor(unsigned index_bits_, unsigned cntr_bits_)
        : BranchPredictor(), index_bits(index_bits_), cntr_bits(cntr_bits_)
    {
        table_entries = 1 << index_bits; // 2^index_bits (2^14=16KB, 2^15=32KB)
        TABLE = new unsigned long long[table_entries];
        memset(TABLE, 0, table_entries * sizeof(*TABLE));

        COUNTER_MAX = (1 << cntr_bits) - 1;
    };
    ~NbitPredictor() { delete TABLE; };

    virtual bool predict(ADDRINT ip, ADDRINT target)
    {
        unsigned int ip_table_index = ip % table_entries;
        unsigned long long ip_table_value = TABLE[ip_table_index];
        unsigned long long prediction = ip_table_value >> (cntr_bits - 1);
        return (prediction != 0);
    };

    virtual void update(bool predicted, bool actual, ADDRINT ip, ADDRINT target)
    {
        unsigned int ip_table_index = ip % table_entries;
        if (actual)
        {
            if (TABLE[ip_table_index] < COUNTER_MAX)
                TABLE[ip_table_index]++;
        }
        else
        {
            if (TABLE[ip_table_index] > 0)
                TABLE[ip_table_index]--;
        }

        updateCounters(predicted, actual);
    };

    virtual string getName()
    {
        std::ostringstream stream;
        stream << "Nbit-" << pow(2.0, double(index_bits)) / 1024.0 << "K-" << cntr_bits;
        return stream.str();
    }

private:
    unsigned int index_bits, cntr_bits;
    unsigned int COUNTER_MAX;

    /* Make this unsigned long long so as to support big numbers of cntr_bits. */
    unsigned long long *TABLE;
    unsigned int table_entries;
};

class TwoBitFSMPredictor : public BranchPredictor
{
public:
    TwoBitFSMPredictor(unsigned index_bits_, unsigned cntr_bits_)
        : BranchPredictor(), index_bits(index_bits_), cntr_bits(cntr_bits_)
    {
        table_entries = 1 << index_bits; // 2^index_bits (2^14=16KB, 2^15=32KB)
        TABLE = new unsigned long long[table_entries];
        memset(TABLE, 0, table_entries * sizeof(*TABLE));

        COUNTER_MAX = (1 << cntr_bits) - 1;
    };
    ~TwoBitFSMPredictor() { delete TABLE; };

    virtual bool predict(ADDRINT ip, ADDRINT target)
    {
        unsigned int ip_table_index = ip % table_entries;
        unsigned long long ip_table_value = TABLE[ip_table_index];
        unsigned long long prediction = ip_table_value >> (cntr_bits - 1);
        return (prediction != 0);
    };

    virtual void update(bool predicted, bool actual, ADDRINT ip, ADDRINT target)
    {
        unsigned int ip_table_index = ip % table_entries;
        if (actual)
        {
            if (TABLE[ip_table_index] == 1)
                TABLE[ip_table_index] = 3;
            else if (TABLE[ip_table_index] < COUNTER_MAX)
                TABLE[ip_table_index]++;
        }
        else
        {

            if (TABLE[ip_table_index] == 2)
                TABLE[ip_table_index] = 0;
            else if (TABLE[ip_table_index] > 0)
                TABLE[ip_table_index]--;
        }

        updateCounters(predicted, actual);
    };

    virtual string getName()
    {
        std::ostringstream stream;
        stream << "2bitFSM-" << pow(2.0, double(index_bits)) / 1024.0 << "K-" << cntr_bits;
        return stream.str();
    }

private:
    unsigned int index_bits, cntr_bits;
    unsigned int COUNTER_MAX;

    /* Make this unsigned long long so as to support big numbers of cntr_bits. */
    unsigned long long *TABLE;
    unsigned int table_entries;
};

class BTBEntry
{
public:
    ADDRINT ip;
    ADDRINT target;
    UINT64 LRUCounter;
    BTBEntry()
        : ip(0), target(0), LRUCounter(0) {}
};

class BTBPredictor : public BranchPredictor
{
public:
    BTBPredictor(int btb_entries, int btb_assoc)
        : table_entries(btb_entries), table_assoc(btb_assoc), access_times(0), correctTargetPredictions(0)
    {

        TABLE = new BTBEntry[table_entries];
    }

    ~BTBPredictor()
    {
        delete TABLE;
    }

    virtual bool predict(ADDRINT ip, ADDRINT target)
    {
        BTBEntry *entry = find(ip);
        if (entry)
        {
            entry->LRUCounter = access_times++;
            return true;
        }
        return false;
    }

    virtual void update(bool predicted, bool actual, ADDRINT ip, ADDRINT target)
    {
        if (predicted && actual)
        {
            BTBEntry *entry = find(ip);
            if (entry->target == target)
                correctTargetPredictions++;
        }
        else if ((!predicted) && actual)
        {
            BTBEntry *entry = find_replacement(ip);
            entry->ip = ip;
            entry->target = target;
            entry->LRUCounter = access_times++;
        }
        else if (predicted && (!actual))
        {
            BTBEntry *entry = find(ip);
            entry->ip = 0;
            entry->target = 0;
            entry->LRUCounter = 0;
        }
        updateCounters(predicted, actual);
    }

    virtual string getName()
    {
        std::ostringstream stream;
        stream << "BTB-" << table_entries << "-" << table_assoc;
        return stream.str();
    }

    UINT64 getNumCorrectTargetPredictions()
    {
        return correctTargetPredictions;
    }

private:
    unsigned int table_entries, table_assoc;
    UINT64 access_times;
    UINT64 correctTargetPredictions;

    BTBEntry *TABLE;
    BTBEntry *find(ADDRINT ip)
    {
        unsigned int set_index = ip % (table_entries / table_assoc);
        for (unsigned int i = 0; i < table_assoc; i++)
        {
            if (TABLE[set_index * table_assoc + i].ip == ip)
            {
                return &TABLE[set_index * table_assoc + i];
            }
        }
        return NULL;
    }
    BTBEntry *find_replacement(ADDRINT ip)
    {
        unsigned int set_index = ip % (table_entries / table_assoc);
        UINT64 minLRU;
        BTBEntry *replacement_entry = &TABLE[set_index * table_assoc];
        for (unsigned int i = 0; i < table_assoc; i++)
        {
            if (i == 0)
            {
                minLRU = TABLE[set_index * table_assoc + i].LRUCounter;
            }
            else
            {
                if (TABLE[set_index * table_assoc + i].LRUCounter < minLRU)
                {
                    minLRU = TABLE[set_index * table_assoc + i].LRUCounter;
                    replacement_entry = &TABLE[set_index * table_assoc + i];
                }
            }
        }
        return replacement_entry;
    };
};

// Fill in the perceptron implementation ...
class PerceptronPredictor : public BranchPredictor
{

public:
    PerceptronPredictor(int _perceptronTableSize, int _historyLength) : perceptronTableSize(_perceptronTableSize), historyLength(_historyLength)
    {
        weightsTable.resize(perceptronTableSize, std::vector<int>(historyLength + 1, 0));
        for (int i = 0; i < perceptronTableSize; ++i)
        {
            for (int j = 0; j <= historyLength; ++j)
            {
                weightsTable[i][j] = rand() % 3 - 1; // Random value between -1 and 1
            }
        }

        history.resize(historyLength, 0);

        kTheta = floor(1.93 * historyLength + 14);
    }

    ~PerceptronPredictor() {}

    virtual bool predict(ADDRINT ip, ADDRINT target)
    {
        int output = compute_output(ip);
        if (output >= 0)
            return true;
        else
            return false;
    }

    virtual void update(bool predicted, bool actual, ADDRINT ip, ADDRINT target)
    {
        if ((!predicted && actual) || (predicted && !actual)) // wrong prediction
        {
            train_perceptron(ip, actual);
        }
        else if ((predicted && actual) || (!predicted && !actual)) // correct prediction
        {
            if (compute_output(ip) <= kTheta)
                train_perceptron(ip, actual);
        }
        if (actual)
            history.push_back(1);
        else
            history.push_back(-1);
        history.erase(history.begin());
        updateCounters(predicted, actual);
    }

    virtual string getName()
    {
        std::ostringstream stream;
        stream << "Perceptron (" << perceptronTableSize << "," << historyLength << ")";
        return stream.str();
    }

private:
    // Table of perceptrons and its number of entries
    std::vector<std::vector<int>> weightsTable;
    int perceptronTableSize;

    // Global History Register and its length
    std::vector<int> history;
    int historyLength;

    // As a threshold we use the optimal value as discussed in the paper (go
    // read the paper!)
    int kTheta;

    int compute_output(ADDRINT ip)
    {
        int index = ip % perceptronTableSize;
        int sum = weightsTable[index][0];
        for (int i = 0; i < historyLength; i++)
        {
            sum += weightsTable[index][i + 1] * history[i];
        }
        return sum;
    }

    void train_perceptron(ADDRINT ip, bool actual)
    {
        int t = 1;
        if (!actual)
            t = -1;
        int index = ip % perceptronTableSize;
        weightsTable[index][0] += t;
        for (int i = 0; i < historyLength; i++)
        {
            if (t == history[i])
                weightsTable[index][i + 1]++;
            else
                weightsTable[index][i + 1]--;
        }
    }
};

// Static Taken Predictor
class StaticTakenPredictor : public BranchPredictor
{
public:
    StaticTakenPredictor() : BranchPredictor(){};
    ~StaticTakenPredictor(){};

    virtual bool predict(ADDRINT ip, ADDRINT target)
    {
        return true;
    };

    virtual void update(bool predicted, bool actual, ADDRINT ip, ADDRINT target)
    {
        updateCounters(predicted, actual);
    };

    virtual string getName()
    {
        std::ostringstream stream;
        stream << "StaticTakenPredictor";
        return stream.str();
    };
};

// Static BackwardTaken-ForwardNotTaken Predictor
class BTFNTPredictor : public BranchPredictor
{
public:
    BTFNTPredictor() : BranchPredictor(){};
    ~BTFNTPredictor(){};

    virtual bool predict(ADDRINT ip, ADDRINT target)
    {
        return target < ip;
    };

    virtual void update(bool predicted, bool actual, ADDRINT ip, ADDRINT target)
    {
        updateCounters(predicted, actual);
    };

    virtual string getName()
    {
        std::ostringstream stream;
        stream << "BTFNTPredictor";
        return stream.str();
    };
};

#endif
