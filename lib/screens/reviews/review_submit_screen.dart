import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/teacher_service.dart';
import '../../services/user_service.dart';
import '../../models/teacher.dart';

class ReviewSubmitScreen extends StatefulWidget {
  final Teacher? teacher;
  final String? teacherName;
  final String? department;

  const ReviewSubmitScreen({
    Key? key,
    this.teacher,
    this.teacherName,
    this.department,
  }) : super(key: key);

  @override
  State<ReviewSubmitScreen> createState() => _ReviewSubmitScreenState();
}

class _ReviewSubmitScreenState extends State<ReviewSubmitScreen> {
  // Constants for consistent styling - matching with home screen
  static const primaryColor = Color(0xFF5E17EB);
  static const darkTextColor = Color(0xFF01242D);
  static const hintTextColor = Color(0xFF708090);
  static const backgroundColor = Color(0xFFF0F8FF);
  static const cardColor = Colors.white;

  // Form controllers
  final _teacherNameController = TextEditingController();
  final _departmentController = TextEditingController();
  final _institutionController = TextEditingController();
  final _reviewTextController = TextEditingController();
  final _courseCodeController = TextEditingController();
  final _courseNameController = TextEditingController();

  // Dropdown values
  List<String> _availableInstitutions = [];
  List<String> _availableDepartments = [];
  List<Map<String, dynamic>> _availableTeachers = [];
  String? _selectedInstitution;
  String? _selectedDepartment;
  String? _selectedTeacher;
  bool _isLoadingInstitutions = false;
  bool _isLoadingDepartments = false;
  bool _isLoadingTeachers = false;
  // Search text controllers for dropdowns
  final _institutionSearchController = TextEditingController();
  final _departmentSearchController = TextEditingController();
  final _teacherSearchController = TextEditingController();

  // Rating values
  double _overallRating = 0;
  final Map<String, double> _ratingBreakdown = {
    'teaching': 0.0,
    'knowledge': 0.0,
    'approachability': 0.0,
    'grading': 0.0,
  };

  // Tags
  final List<String> _availableTags = [
    'Helpful',
    'Clear Explanations',
    'Difficult',
    'Easy Grader',
    'Tough Grader',
    'Project-Based',
    'Engaging',
    'Lots of Assignments',
    'Inspiring',
    'Fair',
  ];

  final List<String> _selectedTags = [];

  bool _isAnonymous = false;
  bool _isSubmitting = false;
  // Create instances of required services
  final TeacherService _teacherService = TeacherService();
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    // Pre-populate fields if teacher is provided
    if (widget.teacher != null) {
      _teacherNameController.text = widget.teacher!.name;
      _departmentController.text = widget.teacher!.department;
      _institutionController.text = widget.teacher!.institution;
      
      // Set the selected values for dropdowns too
      _selectedInstitution = widget.teacher!.institution;
      _selectedDepartment = widget.teacher!.department;
      _selectedTeacher = widget.teacher!.name;
    } else if (widget.teacherName != null && widget.department != null) {
      _teacherNameController.text = widget.teacherName!;
      _departmentController.text = widget.department!;
      
      // Set the selected values for dropdowns too
      _selectedDepartment = widget.department!;
      _selectedTeacher = widget.teacherName!;
    }
    
    // Load institutions for the dropdown
    _loadInstitutions();
  }

  // Load all unique institutions from the teachers collection
  Future<void> _loadInstitutions() async {
    setState(() {
      _isLoadingInstitutions = true;
    });
    
    try {
      final institutions = await _teacherService.getAllInstitutions();
      
      setState(() {
        _availableInstitutions = institutions;
        _isLoadingInstitutions = false;
      });
      
      // If we already have a selected institution (from pre-populated fields),
      // load the departments for that institution
      if (_selectedInstitution != null && _selectedInstitution!.isNotEmpty) {
        _loadDepartments(_selectedInstitution!);
      }
    } catch (e) {
      print('Error loading institutions: $e');
      setState(() {
        _isLoadingInstitutions = false;
      });
      _showError('Failed to load institutions. Please try again.');
    }
  }
    // Load departments for a specific institution
  Future<void> _loadDepartments(String institution) async {
    setState(() {
      _isLoadingDepartments = true;
      _availableDepartments = [];
      
      // Only reset these if we don't have a pre-selected teacher
      if (widget.teacher == null) {
        _selectedDepartment = null;
        _departmentController.text = '';
        
        // Reset teacher-related fields too since department is changing
        _availableTeachers = [];
        _selectedTeacher = null;
        _teacherNameController.text = '';
      }
    });
    
    try {
      final departments = await _teacherService.getDepartmentsByInstitution(institution);
      
      setState(() {
        _availableDepartments = departments;
        _isLoadingDepartments = false;
        
        // If we already have a selected department (from pre-populated fields)
        // and it exists in the available departments, keep it selected
        if (_departmentController.text.isNotEmpty && 
            departments.contains(_departmentController.text)) {
          _selectedDepartment = _departmentController.text;
          _loadTeachers(_selectedInstitution!, _selectedDepartment!);
        }
      });
    } catch (e) {
      print('Error loading departments: $e');
      setState(() {
        _isLoadingDepartments = false;
      });
      _showError('Failed to load departments. Please try again.');
    }
  }
    // Load teachers for a specific institution and department
  Future<void> _loadTeachers(String institution, String department) async {
    setState(() {
      _isLoadingTeachers = true;
      _availableTeachers = [];
      
      // Only reset teacher if not coming from teacher detail screen
      if (widget.teacher == null) {
        _selectedTeacher = null;
        _teacherNameController.text = '';
      }
    });
    
    try {
      final teachers = await _teacherService.getTeachersByInstitutionAndDepartment(
        institution,
        department,
      );
      
      setState(() {
        _availableTeachers = teachers.map((teacher) => {
          'name': teacher.name,
          'department': teacher.department,
          'institution': teacher.institution,
        }).toList();
        _isLoadingTeachers = false;
        
        // If we already have a selected teacher (from pre-populated fields)
        // and it exists in the available teachers, keep it selected
        if (_teacherNameController.text.isNotEmpty) {
          final existingTeacher = _availableTeachers.where(
            (teacher) => teacher['name'] == _teacherNameController.text,
          ).isNotEmpty ? _availableTeachers.firstWhere(
            (teacher) => teacher['name'] == _teacherNameController.text,
          ) : null;
          
          if (existingTeacher != null) {
            _selectedTeacher = existingTeacher['name'];
          }
        }
      });
    } catch (e) {
      print('Error loading teachers: $e');
      setState(() {
        _isLoadingTeachers = false;
      });
      _showError('Failed to load teachers. Please try again.');
    }
  }

  // Selection handlers for dropdowns
  void _handleInstitutionSelected(String institution) {
    setState(() {
      _selectedInstitution = institution;
      _institutionController.text = institution;
    });
    _loadDepartments(institution);
  }
  
  void _handleDepartmentSelected(String department) {
    setState(() {
      _selectedDepartment = department;
      _departmentController.text = department;
    });
    _loadTeachers(_selectedInstitution!, department);
  }
  
  void _handleTeacherSelected(Map<String, dynamic> teacher) {
    setState(() {
      _selectedTeacher = teacher['name'];
      _teacherNameController.text = teacher['name'];
    });
  }

  @override
  void dispose() {
    _teacherNameController.dispose();
    _departmentController.dispose();
    _institutionController.dispose();
    _reviewTextController.dispose();
    _courseCodeController.dispose();
    _courseNameController.dispose();
    _institutionSearchController.dispose();
    _departmentSearchController.dispose();
    _teacherSearchController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_validateForm()) {
      setState(() {
        _isSubmitting = true;
      });      try {
        // Check the review content first
        final reviewText = _reviewTextController.text;
        try {
          final censorship = await _userService.checkReviewContent(reviewText);

          // Check if the review was accepted
          if (censorship['accepted'] != true) {
            // Store the rejected review in the rejectedReviews collection
            await _userService.storeRejectedReview(
              reviewText: reviewText,
              teacherName: _teacherNameController.text,
              teacherDepartment: _departmentController.text,
              rating: _overallRating,
              ratingBreakdown: _ratingBreakdown,
              institution: _institutionController.text,
              courseCode: _courseCodeController.text,
              courseName: _courseNameController.text,
              tags: _selectedTags,
              isAnonymous: _isAnonymous,
              rejectionReason: censorship['reason'],
            );
            
            // Review was rejected by the AI, show the appropriate message
            _showError(
                "Your review contains inappropriate language as detected by our AI. Please rewrite your review and try again.");
            setState(() {
              _isSubmitting = false;
            });
            return;
          }

          // If we get here, the review content was accepted, so continue with submission
          await _teacherService.addReview(
            teacherName: _teacherNameController.text,
            teacherDepartment: _departmentController.text,
            text: reviewText,
            rating: _overallRating,
            ratingBreakdown: _ratingBreakdown,
            institution: _institutionController.text,
            courseCode: _courseCodeController.text,
            courseName: _courseNameController.text,
            tags: _selectedTags,
            isAnonymous: _isAnonymous,
          );

          if (mounted) {
            _showSuccessMessage();
            // Go back after success
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.of(context)
                    .pop(true); // Return true for successful submission
              }
            });
          }
        } catch (e) {
          // Handle specific error messages from the censorship check
          if (e.toString().contains('validation_connectivity_error')) {
            _showError(
                "Unable to connect to the server to validate the review language. Please try again later.");
          } else if (e.toString().contains('validation_server_error')) {
            _showError(
                "Unable to connect to the server to validate the review language. Please try again later.");
          } else {
            _showError("Error validating review: ${e.toString()}");
          }
          setState(() {
            _isSubmitting = false;
          });
        }
      } catch (e) {
        print('Error submitting review: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error submitting review: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  bool _validateForm() {
    // Basic validation
    if (_teacherNameController.text.isEmpty) {
      _showError('Please enter teacher name');
      return false;
    }

    if (_departmentController.text.isEmpty) {
      _showError('Please enter department');
      return false;
    }

    if (_institutionController.text.isEmpty) {
      _showError('Please enter university/institution');
      return false;
    }

    if (_reviewTextController.text.isEmpty) {
      _showError('Please write a review');
      return false;
    }

    if (_overallRating == 0) {
      _showError('Please provide an overall rating');
      return false;
    }

    // Check if any rating is 0
    for (final key in _ratingBreakdown.keys) {
      if (_ratingBreakdown[key] == 0) {
        _showError('Please rate $key');
        return false;
      }
    }

    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Review submitted successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'Write a Review',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Teacher Information",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: darkTextColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                      // 1. University/Institution dropdown (first)
                    _buildSearchableDropdown<String>(
                      label: "University/Institution",
                      hint: "Select a university/institution",
                      items: _availableInstitutions,
                      isLoading: _isLoadingInstitutions,
                      selectedValue: _selectedInstitution,
                      getLabel: (item) => item,
                      searchController: _institutionSearchController,
                      onItemSelected: _handleInstitutionSelected,
                      enabled: true,
                      emptyMessage: "No institutions found. Please try a different search term or add a new institution.",
                    ),
                    
                    const SizedBox(height: 12),
                      // 2. Department dropdown (second)
                    _buildSearchableDropdown<String>(
                      label: "Department",
                      hint: "Select a department",
                      items: _availableDepartments,
                      isLoading: _isLoadingDepartments,
                      selectedValue: _selectedDepartment,
                      getLabel: (item) => item,
                      searchController: _departmentSearchController,
                      onItemSelected: _handleDepartmentSelected,
                      enabled: _selectedInstitution != null,
                      emptyMessage: _selectedInstitution == null 
                          ? "Please select an institution first" 
                          : "No departments found for this institution.",
                    ),
                    
                    const SizedBox(height: 12),
                      // 3. Teacher Name dropdown (third)
                    _buildSearchableDropdown<Map<String, dynamic>>(
                      label: "Teacher Name",
                      hint: "Select a teacher",
                      items: _availableTeachers,
                      isLoading: _isLoadingTeachers,
                      selectedValue: (_availableTeachers.isNotEmpty && _selectedTeacher != null &&
                        _availableTeachers.where((teacher) => teacher['name'] == _selectedTeacher).isNotEmpty)
                        ? _availableTeachers.firstWhere((teacher) => teacher['name'] == _selectedTeacher)
                        : null,
                      getLabel: (item) => item['name'] as String,
                      searchController: _teacherSearchController,
                      onItemSelected: _handleTeacherSelected,
                      enabled: _selectedDepartment != null,
                      emptyMessage: _selectedDepartment == null 
                          ? "Please select a department first" 
                          : "No teachers found for this department and institution.",
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Course information remains unchanged
                    _buildTextField(
                      controller: _courseCodeController,
                      label: "Course Code (optional)",
                      hint: "e.g., CS101, ECON202",
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _courseNameController,
                      label: "Course Name (optional)",
                      hint: "e.g., Introduction to Programming",
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Overall Rating
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Overall Rating",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: darkTextColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: RatingBar.builder(
                        initialRating: _overallRating,
                        minRating: 1,
                        direction: Axis.horizontal,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemPadding:
                            const EdgeInsets.symmetric(horizontal: 4.0),
                        itemBuilder: (context, _) => Icon(
                          Icons.star,
                          color: primaryColor,
                        ),
                        onRatingUpdate: (rating) {
                          setState(() {
                            _overallRating = rating;
                          });
                        },
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _overallRating > 0
                              ? _overallRating.toString()
                              : "Select a rating",
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 16,
                            color: _overallRating > 0
                                ? darkTextColor
                                : hintTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Detailed Ratings
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Rate Specifically",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: darkTextColor,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Generate rating bars for each category
                    ...['teaching', 'knowledge', 'approachability', 'grading']
                        .map((category) {
                      String displayName =
                          category[0].toUpperCase() + category.substring(1);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: darkTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: RatingBar.builder(
                                    initialRating:
                                        _ratingBreakdown[category] ?? 0,
                                    minRating: 1,
                                    direction: Axis.horizontal,
                                    allowHalfRating: true,
                                    itemCount: 5,
                                    itemSize: 30,
                                    itemBuilder: (context, _) => Icon(
                                      Icons.star,
                                      color: primaryColor,
                                    ),
                                    onRatingUpdate: (rating) {
                                      setState(() {
                                        _ratingBreakdown[category] = rating;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  (_ratingBreakdown[category] ?? 0) > 0
                                      ? (_ratingBreakdown[category] ?? 0)
                                          .toString()
                                      : "-",
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: (_ratingBreakdown[category] ?? 0) > 0
                                        ? darkTextColor
                                        : hintTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Tags
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Add Tags (Optional)",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: darkTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Select tags that describe this teacher",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        color: hintTextColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableTags.map((tag) {
                        final isSelected = _selectedTags.contains(tag);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedTags.remove(tag);
                              } else {
                                _selectedTags.add(tag);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected ? primaryColor : Colors.grey[200],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color:
                                    isSelected ? Colors.white : darkTextColor,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Review Text
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Write Your Review",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: darkTextColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _reviewTextController,
                      maxLines: 5,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        color: darkTextColor,
                      ),
                      decoration: InputDecoration(
                        hintText: "Share your experience with this teacher...",
                        hintStyle: const TextStyle(
                          fontFamily: 'Manrope',
                          color: hintTextColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Anonymous Option
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Post Anonymously",
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: darkTextColor,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Your name won't be displayed with the review",
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 14,
                              color: hintTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isAnonymous,
                      onChanged: (value) {
                        setState(() {
                          _isAnonymous = value;
                        });
                      },
                      activeColor: primaryColor,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: primaryColor.withOpacity(0.5),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : const Text(
                          "Submit Review",
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: darkTextColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 16,
            color: darkTextColor,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: 'Manrope',
              color: hintTextColor,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            filled: true,
            fillColor: readOnly ? Colors.grey[100] : Colors.grey[50],
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSearchableDropdown<T>({
    required String label,
    required String hint,
    required List<T> items,
    required bool isLoading,
    required T? selectedValue,
    required String Function(T item) getLabel,
    required TextEditingController searchController,
    required Function(T) onItemSelected,
    bool enabled = true,
    String? emptyMessage,
  }) {
    // Make sure Map<String, dynamic> type is handled correctly
    bool itemsEqual(T? a, T? b) {
      if (a == null || b == null) return a == b;
      if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
        // For Map types, compare by the 'name' field
        return a['name'] == b['name'];
      }
      return a == b;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: darkTextColor,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: !enabled
              ? null
              : () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) {
                      return StatefulBuilder(
                        builder: (context, setState) {
                          // Filter items based on search
                          final searchText = searchController.text.toLowerCase();
                          final filteredItems = items.where((item) {
                            final label = getLabel(item).toLowerCase();
                            return label.contains(searchText);
                          }).toList();
                          
                          return Container(
                            height: MediaQuery.of(context).size.height * 0.7,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(20.0),
                                topRight: Radius.circular(20.0),
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  width: 40,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(2.5),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 8.0,
                                  ),
                                  child: TextField(
                                    controller: searchController,
                                    style: const TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 16,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Search...',
                                      prefixIcon: const Icon(Icons.search),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {});
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: isLoading
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : filteredItems.isEmpty
                                          ? Center(
                                              child: Padding(
                                                padding: const EdgeInsets.all(20.0),
                                                child: Text(
                                                  emptyMessage ?? 'No items found',
                                                  style: const TextStyle(
                                                    fontFamily: 'Manrope',
                                                    fontSize: 16,
                                                    color: hintTextColor,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            )
                                          : ListView.builder(
                                              itemCount: filteredItems.length,
                                              itemBuilder: (context, index) {
                                                final item = filteredItems[index];
                                                final isSelected = itemsEqual(selectedValue, item);
                                                
                                                return ListTile(
                                                  title: Text(
                                                    getLabel(item),
                                                    style: TextStyle(
                                                      fontFamily: 'Manrope',
                                                      fontWeight: isSelected
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                      color: isSelected
                                                          ? primaryColor
                                                          : darkTextColor,
                                                    ),
                                                  ),
                                                  trailing: isSelected
                                                      ? const Icon(
                                                          Icons.check_circle,
                                                          color: primaryColor,
                                                        )
                                                      : null,
                                                  onTap: () {
                                                    onItemSelected(item);
                                                    searchController.clear();
                                                    Navigator.pop(context);
                                                  },
                                                );
                                              },
                                            ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[300]!,
              ),
              color: enabled ? Colors.grey[50] : Colors.grey[100],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedValue != null
                        ? getLabel(selectedValue)
                        : hint,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      color: selectedValue != null
                          ? darkTextColor
                          : hintTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                    ),
                  )
                else
                  const Icon(
                    Icons.arrow_drop_down,
                    color: hintTextColor,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
