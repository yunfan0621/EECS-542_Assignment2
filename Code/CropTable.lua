local CropTable, Parent = torch.class('nn.CropTable', 'nn.Module')

function CropTable:__init(axis_array, offset_array)
    Parent.__init(self)
    self.axis_array = axis_array
    self.offset_array = offset_array
end

-- input should be like {tensor1, tensor2}, crop tensor1 to be the same size as tensor2
-- on the axis with certain offset
function CropTable:updateOutput(input)
   -- print('=======================================')
   -- print('input1:')
   -- print(input[1]:size())
   -- print('input2:')
   -- print(input[2]:size())

   -- print('axis_array:')
   -- print(self.axis_array)
   -- print('offest_array:')
   -- print(self.offset_array)
   -- print('=======================================')

    local output1 = input[1]
    for i = 1, #self.axis_array do
        output1 = output1:narrow(self.axis_array[i], self.offset_array[i], input[2]:size()[self.axis_array[i]])
    end
    self.output = {output1, input[2]}
    return self.output
end

-- gradInput should be like {tensor1, tensor2}, where gradInput[1] should be the same size as input[1](scale back)
function CropTable:updateGradInput(input, gradOutput)
    local gradInput1 = gradOutput[1]:double()

    for i = 1, #self.axis_array do
        local leftPaddingSize = gradInput1:size()
        leftPaddingSize[self.axis_array[i]] = self.offset_array[i] - 1
        local rightPaddingSize = gradInput1:size()
        rightPaddingSize[self.axis_array[i]] = input[1]:size()[self.axis_array[i]] - input[2]:size()[self.axis_array[i]] - self.offset_array[i] + 1

        if rightPaddingSize[self.axis_array[i]] == 0 then
            local leftPadding = torch.zeros(leftPaddingSize)
            gradInput1 = torch.cat({leftPadding, gradInput1}, self.axis_array[i])
        else 
            local leftPadding = torch.zeros(leftPaddingSize)
            local rightPadding = torch.zeros(rightPaddingSize)
            gradInput1 = torch.cat({leftPadding, gradInput1, rightPadding}, self.axis_array[i])
        end
    end
    self.gradInput = {gradInput1:cuda(), gradOutput[2]:cuda()}
    -- self.gradInput = {gradInput1, gradOutput[2]}
    return self.gradInput
end
