#### Initialization
# set user params
n_pu=c(16, 100, 1000, 10000)
n_rep=100

# load deps
library(raster)
library(maptools)
library(Rcpp)
library(inline)
library(microbenchmark)

# define functions
test=function(){source('/home/jeff/Documents/temp/marxan_bl_benchmark.R')}

makePUs=function(n) {
  rast=raster(matrix(NA, ceiling(sqrt(n)), ceiling(sqrt(n))))
  rast=setValues(rast, seq_len(ncell(rast)))
  sppolyDF=rasterToPolygons(rast, n=4, dissolve=FALSE)
  return(SpatialPolygons2PolySet(sppolyDF))
}

cppFunction(includes='
      #include <vector>
      #include <string>
      #include <algorithm>
      #include <unordered_map>
      #include <iomanip>
      #include <iostream>
      #include <Rcpp.h>

      template<int P>
      inline double Pow(double x) {
	  return (Pow<P-1>(x) * x);
      }

      template<>
      inline double Pow<1>(double x) {
	  return (x);
      }

      template<>
      inline double Pow<0>(double x) {
	  return (1.0);
      }

      double distance(double x0, double y0, double x1, double y1) {
	// return(sqrt(std::abs(Pow<2>(x0-x1)) + std::abs(Pow<2>(y0-y1))));
	return(sqrt(std::abs(Pow<2>(x0-x1)) + std::abs(Pow<2>(y0-y1))));
      }
      
      template<typename T>
      inline std::string num2str(T number, int precision=10)
      {
	  std::ostringstream ss;
	  ss << std::setprecision(precision) << number;
	  return(ss.str());
      }
            
      class LINE
      {
	      public:
		      // declare constructor
		      LINE(){};
		      LINE(int pid, int pos0, int pos1, double x0, double y0, double x1, double y1, int tol) 
			: _pid(pid), _pos0(pos0), _pos1(pos1), _x0(x0), _y0(y0), _x1(x1), _y1(y1), _len(distance(x0,y0,x1,y1))   {
			  if (_x0 > _x1 || _y0 > _y1) {
			    _key = num2str<double>(_x0,tol) + "," + num2str<double>(_y0,tol) + ";" +num2str<double>(_x1,tol) + "," + num2str<double>(_y1,tol);
			  } else {
			    _key = num2str<double>(_x1,tol) + "," + num2str<double>(_y1,tol) + ";" +num2str<double>(_x0,tol) + "," + num2str<double>(_y0,tol);
			  }
		      };
		      // declare deconstructor
		      ~LINE(){};

		      // declare methods
		      inline const std::string getLID() const {
			return(_key + ";" + num2str<int>(_pid) + ";" +num2str<int>(_pos0) + "," + num2str<int>(_pos1));
		      }
		      
		      // declare fields
		      int _pid;
		      int _pos0;
		      int _pos1;
		      double _x0;
		      double _y0;
		      double _x1;
		      double _y1;
		      double _len;
		      std::string _key;
      };
',code='
	Rcpp::List createBoundaryDF(IntegerVector PID, IntegerVector POS, NumericVector X, NumericVector Y, double tolerance=0.001, double lengthFactor=1.0, double edgeFactor=1.0) {
		//// initialization
		/// declare variables and preallocate memory
		// calculation vars
		std::unordered_multimap<std::string, LINE> line_UMMAP;
		std::vector<std::string> key_VSTR;
		key_VSTR.reserve(PID.size()*10);
		int tol=(1.0/tol);
		
		// export vars
		std::vector<int> puid0_INT;
		puid0_INT.reserve(PID.size()*10);
		std::vector<int> puid1_INT;
		puid1_INT.reserve(PID.size()*10);
		std::vector<double> length_DBL;
		length_DBL.reserve(PID.size()*10);
		std::vector<std::string> warning_VSTR;
		warning_VSTR.reserve(PID.size()*10);
		
		//// preliminary processing
		// generate lines
		int currPIdFirstElement=0;
		LINE currLine;
		for (int i=1; i!=PID.size(); ++i) {
		  if (PID[i]==PID[currPIdFirstElement]) {
		    currLine=LINE(PID[i], POS[i], POS[i-1], X[i], Y[i], X[i-1], Y[i-1], tol);
		    line_UMMAP.insert(std::pair<std::string, LINE>(currLine._key, currLine)); 
		    key_VSTR.push_back(currLine._key);
		  } else {
		    currPIdFirstElement=i;
		  }
		}
		
		// obtain unique keys
		key_VSTR.shrink_to_fit();
		sort(key_VSTR.begin(), key_VSTR.end());
		key_VSTR.erase(unique(key_VSTR.begin(), key_VSTR.end()), key_VSTR.end());
		key_VSTR.shrink_to_fit();
				
		//// main processing
		//declare local vars
		int currPID_INT;
		auto range=line_UMMAP.equal_range(key_VSTR[0]);
		auto it=range.first;
		for (auto i=key_VSTR.cbegin(); i!=key_VSTR.cend(); ++i) {
		  // init
		  range=line_UMMAP.equal_range(*i);
    
		  // store pu data
		  it=range.first;
		  currPID_INT=(it->second)._pid;
		  puid0_INT.push_back(currPID_INT);
		  length_DBL.push_back((it->second)._len * lengthFactor);		    
		  ++it;
		  if (it == range.second) {
		    // store same pid if no duplicate lines
		    puid1_INT.push_back(currPID_INT);
		  } else {
		    // std::cout << "here" << std::endl;
		    // store second pid at least one duplicate lines
		    puid1_INT.push_back((it->second)._pid);
		    // check to see if more than 2 spatially identical lines
		    ++it;
		    if (it != range.second) {
		      it=range.first;
		      // std::cout << "key = " << it->first << std::endl;
		      for (; it!=range.second; ++it) {
			  // std::cout << "key = " << it->first << "/ " << (it->second)._key << "; lid = " << (it->second).getLID() << std::endl;
			  warning_VSTR.push_back((it->second).getLID());
		      }
		    }
		  }
		}
		
		//// exports
 		return(
 		  Rcpp::List::create(
		    Rcpp::Named("bldf") = Rcpp::DataFrame::create(Named("id1")=puid0_INT, Named("id2")=puid1_INT, Named("boundary")=length_DBL),
 		    Rcpp::Named("warnings")=warning_VSTR
 		  )
 		);
	}
', plugins=c("cpp11"),
verbose=FALSE
)

#### Preliminary processing
## generate pu data
# generate raster
cat("generating pu data..\n")
puLST=lapply(n_pu, makePUs)

#### Main processing
# run benchmark
cat("generating benchmarking data..\n")
bench=microbenchmark(
  "n = 16" = createBoundaryDF(puLST[[1]][[1]], puLST[[1]][[2]], puLST[[1]][[3]], puLST[[1]][[4]]),
  "n = 100" = createBoundaryDF(puLST[[2]][[1]], puLST[[2]][[2]], puLST[[2]][[3]], puLST[[2]][[4]]),
  "n = 1000" = createBoundaryDF(puLST[[3]][[1]], puLST[[3]][[2]], puLST[[3]][[3]], puLST[[3]][[4]]),
  "n = 10000" = createBoundaryDF(puLST[[4]][[1]], puLST[[4]][[2]], puLST[[4]][[3]], puLST[[4]][[4]]),
  times=n_rep, unit="s"
)
bench2=microbenchmark:::convert_to_unit(bench, "s")
bench2$expr=bench$expr
class(bench2)="data.frame"

#### Exports
tiff("/home/jeff/Documents/temp/benchmark.png")
boxplot(time~expr, data=bench2, ylab="time (s)", las=1)
dev.off()

