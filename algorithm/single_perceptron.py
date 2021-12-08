import numpy as np

N = 64;  #vector size
M = 5;
data_width = 8;
weight_width = 8;

print("Running single perceptron script!")

#create m samples of vectors with length N and different weights for each vector.
data_in_vector = np.random.rand(N, M);
weights_n      = np.random.rand(N, M);
print("Creating " + str(M) + " vectors with length " + str(N))
#normalise and spread it across the datawidth specified.
data_in_vector_norm = data_in_vector/np.max(data_in_vector);
data_in_vector_fi  = np.ceil(data_in_vector_norm*(2**data_width)) - 1;

weights_n_norm = weights_n/np.max(weights_n);
weights_n_fi = np.ceil(weights_n_norm*(2**weight_width)) - 1;

#compute the result.
accumulated_result = np.zeros(M);
threshold_vector = np.random.rand(M);
for v_i in range(M):
    weight = np.reshape(weights_n_fi[:,v_i], (N,1))
    vector = np.reshape(data_in_vector_fi[:,v_i], (N,1))
    accumulated_result[v_i] = np.dot(weight.T, vector)
     
#accumulated_result = np.dot(data_in_vector, weights_n)
print("accumulated result : " + str(accumulated_result))

threshold_vector_norm = threshold_vector/np.max(threshold_vector)
threshold_vector_fi   = np.ceil(threshold_vector_norm*np.max(accumulated_result))
print("threshold vector : " + str(threshold_vector_fi))

comparator_result = accumulated_result > threshold_vector_fi
print("threshold vector : " + str(comparator_result))
print("Generating output files!")

#generate output files
data_in_file_name = "data_in_Vect_s" + str(N) + "_w" + str(data_width) +"_M"\
    + str(M) + "_Weig_w" + str(weight_width) + ".dat"
weight_file_name =   "weight_Vect_s" + str(N) + "_w" + str(data_width) +"_M"\
    + str(M) + "_Weig_w" + str(weight_width) + ".dat"  

thre_sum_comp_file_name = "thre_sum_comp_s" + str(N) + "_w" + str(data_width) +"_M"\
    + str(M) + "_Weig_w" + str(weight_width) + ".dat"  

data_in_file_handle = open(data_in_file_name, "w")
weight_file_handle = open(weight_file_name, "w")
thre_sum_comp_file_handle = open(thre_sum_comp_file_name, "w")


for v_i in range(M):
    for e_i in range(N):
        data_in_file_handle.write(str(int(data_in_vector_fi[e_i, v_i])) + "\n")
        weight_file_handle.write(str(int(weights_n_fi[e_i, v_i])) + "\n")
    thre_sum_comp_file_handle.write(str(int(threshold_vector_fi[v_i])) +"," +\
                                    str(int(accumulated_result[v_i])) +"," +\
                                    str(int(comparator_result[v_i])) +"\n")


data_in_file_handle.close()
weight_file_handle.close()
thre_sum_comp_file_handle.close()