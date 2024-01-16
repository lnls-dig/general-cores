import matplotlib.pyplot as plt
import pandas as pd

def main():
    filename = "res.txt"
    data = pd.read_csv(filename, header=None, names=["ix", "iy", "iz","ox", "oy", "oz", "ex", "ey", "ez", "mode", "submode"])
    
    data["mode"][data["mode"] == 0] = "vector"
    data["mode"][data["mode"] == 1] = "rotate"

    data["submode"][data["submode"] == 0] = "circular"
    data["submode"][data["submode"] == 1] = "linear"

    data.insert(len(data.columns), "err_x",abs(data["ox"]-data["ex"]))
    data.insert(len(data.columns), "err_y",abs(data["oy"]-data["ey"]))
    data.insert(len(data.columns), "err_z",abs(data["oz"]-data["ez"]))

    print(data)
    
    rotcirc      = data[data["mode"] == "rotate"]
    rotcirc      = rotcirc[rotcirc["submode"] == "circular"]

    rotlinear      = data[data["mode"] == "rotate"]
    rotlinear      = rotlinear[rotlinear["submode"] == "linear"]
    
    vectcirc      = data[data["mode"] == "vector"]
    vectcirc      = vectcirc[vectcirc["submode"] == "circular"]

    vectlinear      = data[data["mode"] == "vector"]
    vectlinear      = vectlinear[vectlinear["submode"] == "linear"]
    
    print(rotcirc      )
    print(rotlinear    )
    print(vectcirc   )
    print(vectlinear )

    # How is error defined ?
    # rotate/Circular -> 2 errors, xo and yo
    # rotate/linear -> 2 errors, x and y
    # vector/circular -> 2 errors, x and z
    # vector/linear -> 2 errors, x and z
    
    
    import numpy as np
     
    fig = plt.figure()
     
    # syntax for 3-D projection
    ax = plt.axes(projection ='3d')
     
    # defining axes
    x = vectcirc["ix"]
    y = vectcirc["iy"]
    z = vectcirc["iz"]
    err_x = vectcirc["err_x"]
    err_y = vectcirc["err_y"]
    err_z = vectcirc["err_z"]

    
    plt.subplot(4,3,1)
    plt.plot(x, err_x, 'x')
    plt.plot(y, err_x, 'x')
    plt.plot(z, err_x, 'x')
    #plt.legend(["errx = f(x)", "errx = f(y)", "errx = f(z)"])
    plt.title("vect/circle : magnitude error")

    plt.subplot(4,3,2)
    plt.plot(x, err_y, 'x')
    plt.plot(y, err_y, 'x')
    plt.plot(z, err_y, 'x')
    #plt.legend(["erry = f(x)", "erry = f(y)", "erry = f(z)"])
    plt.title("vector/circle")

    plt.subplot(4,3,3)
    plt.plot(x, err_z, 'x')
    plt.plot(y, err_z, 'x')
    plt.plot(z, err_z, 'x')
    #plt.legend(["errz = f(x)", "errz = f(y)", "errz = f(z)"])
    plt.title("vector/circle : angle error")

    x = rotcirc["ix"]
    y = rotcirc["iy"]
    z = rotcirc["iz"]
    err_x = rotcirc["err_x"]
    err_y = rotcirc["err_y"]
    err_z = rotcirc["err_z"]

    
    plt.subplot(4,3,4)
    plt.plot(x, err_x, 'x')
    plt.plot(y, err_x, 'x')
    plt.plot(z, err_x, 'x')
    #plt.legend(["errx = f(x)", "errx = f(y)", "errx = f(z)"])
    plt.title("rotate/circle")

    plt.subplot(4,3,5)
    plt.plot(x, err_y, 'x')
    plt.plot(y, err_y, 'x')
    plt.plot(z, err_y, 'x')
    #plt.legend(["erry = f(x)", "erry = f(y)", "erry = f(z)"])
    plt.title("rotate/circle")

    plt.subplot(4,3,6)
    plt.plot(x, err_z, 'x')
    plt.plot(y, err_z, 'x')
    plt.plot(z, err_z, 'x')
    #plt.legend(["errz = f(x)", "errz = f(y)", "errz = f(z)"])
    plt.title("rotate/circle")

    x = rotlinear["ix"]
    y = rotlinear["iy"]
    z = rotlinear["iz"]
    err_x = rotlinear["err_x"]
    err_y = rotlinear["err_y"]
    err_z = rotlinear["err_z"]
    
    plt.subplot(4,3,7)
    plt.plot(x, err_x, 'x')
    plt.plot(y, err_x, 'x')
    plt.plot(z, err_x, 'x')
    #plt.legend(["errx = f(x)", "errx = f(y)", "errx = f(z)"])
    plt.title("rotate/linear")

    plt.subplot(4,3,8)
    plt.plot(x, err_y, 'x')
    plt.plot(y, err_y, 'x')
    plt.plot(z, err_y, 'x')
    #plt.legend(["erry = f(x)", "erry = f(y)", "erry = f(z)"])
    plt.title("rotate/linear")

    plt.subplot(4,3,9)
    plt.plot(x, err_z, 'x')
    plt.plot(y, err_z, 'x')
    plt.plot(z, err_z, 'x')
    #plt.legend(["errz = f(x)", "errz = f(y)", "errz = f(z)"])
    plt.title("rotate/linear")

    x = vectlinear["ix"]
    y = vectlinear["iy"]
    z = vectlinear["iz"]
    xy = vectlinear["iy"]/vectlinear["ix"]
    err_x = vectlinear["err_x"]
    err_y = vectlinear["err_y"]
    err_z = vectlinear["err_z"]

    
    plt.subplot(4,3,10)
    plt.plot(xy, err_x, 'x')
    plt.plot(xy, err_y, 'x')
    plt.plot(xy, err_z, 'x')
    #plt.legend(["errx = f(y/x)", "erry = f(y/x)", "errz = f(y/x)"])
    plt.title("vector/linear: ratio error = f(ratio)")

    plt.subplot(4,3,11)
    plt.plot(x, err_y, 'x')
    plt.plot(y, err_y, 'x')
    plt.plot(z, err_y, 'x')
    #plt.legend(["erry = f(x)", "erry = f(y)", "erry = f(z)"])
    plt.title("vector/linear")

    plt.subplot(4,3,12)
    plt.plot(x, err_z, 'x')
    plt.plot(y, err_z, 'x')
    plt.plot(z, err_z, 'x')
    #plt.legend(["errz = f(x)", "errz = f(y)", "errz = f(z)"])
    plt.title("vector/linear: ratio error")

     
     
    plt.show()
    

if __name__ == "__main__":
    main()