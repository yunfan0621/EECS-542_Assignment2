require 'nn'
require 'nngraph'
require 'paths'
require 'cunn'
require 'cudnn'
require 'optim'

-- load the data
paths.dofile('load.lua')
-- load the functions to calculate metrics 
paths.dofile('metrics.lua')
-- write the loss to a text file and read from there to plot the loss as training proceeds
logger = optim.Logger('loss_log.txt')
-- states variables for the optimization process
local optimState = {
	learningRate = 0.0001, -- learning rate 10^-4 as per the paper
	-- learningRateDecay = 1e-4,
	momentum = 0.90,
	weightDecay = 0.0005
}
-- hyperparameter
local config = {
	batch_size = 20,
	max_epoch = 736, -- max number of epochs
	trainset_size = trainset:size(),
	valset_size = valset:size(),
	testset_size = testset:size()
}
-- train 
function train()
	-- load net module
	paths.dofile('FCN8.lua')
	fcn_net = fcn_net:cuda()
	print(fcn_net)
	-- criterion for loss
	criterion = cudnn.SpatialCrossEntropyCriterion() -- how to implement 'normalize: false'
	criterion = criterion:cuda()
	-- trainset already loaded

	-- start to train the net
	params, gradParams = fcn_net:getParameters()

	for epoch = 1, config.max_epoch do
   	-- local function we give to optim
   	-- it takes current weights as input, and outputs the loss
   	-- and the gradient of the loss with respect to the weights
   	-- gradParams is calculated implicitly by calling 'backward',
   	-- because the model's weight and bias gradient tensors
   	-- are simply views onto gradParams

   		cur_loss = 0
   		for iteration = 1, config.trainset_size do
	   		function feval(params)
	      		gradParams:zero()
				batchInputs = trainset[iteration][1]:cuda()
				batchLabels = trainset[iteration][2]:cuda()

				local outputs = fcn_net:forward(batchInputs)
				-- ignore_label: 255; pixels of 255 are not counted into loss function
				outputs[batchLabels:eq(255)] = 255
	      		local loss = criterion:forward(outputs, batchLabels)
	      		local dloss_doutputs = criterion:backward(outputs, batchLabels)
	      		fcn_net:backward(batchInputs, dloss_doutputs)
	      		return loss, gradParams
	   		end
	   		_, batch_loss = optim.sgd(feval, params, optimState)
	   		cur_loss = cur_loss + batch_loss[1]
	   	end
   		print('-----------------------------------------------------------')
   		print('epoch = ' .. epoch .. ',    current loss = ' .. current_loss)
   		-- write the loss since this epoch to the log
   		logger:add{['training error'] = current_loss}
   		logger:style{['training error'] = '-'}
   		logger:plot() 
		trainset:shuffle()
	end
end
-- test
function test()
	for i = 1, testset_size do 
		test_image = testset[i][1]:cuda()
		true_seg = testset[i][2]:cuda()
		net_seg = fcn_net:forward(test_image)
		compute_hist(net_seg,true_seg)
	end

	print(string.format("%2d  %6.2f %6.2f", i, myPrediction[1], text[i]))
end
-- run
train()
test()